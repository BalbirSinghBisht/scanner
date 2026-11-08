package com.mediabackup.scanner.scanner

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log

object MediaSyncWatchdog {
    private const val TAG = "MediaSyncWatchdog"
    const val ACTION_WATCHDOG_WAKE = "com.mediabackup.scanner.ACTION_WATCHDOG_WAKE"
    private const val REQUEST_CODE = 44921
    private const val INTERVAL_MILLIS = 10 * 60 * 1000L // 10 minutes heartbeat

    private var wakeLock: PowerManager.WakeLock? = null
    private var continuousWakeLock: PowerManager.WakeLock? = null

    /**
     * Acquires an un-expiring partial CPU WakeLock.
     * Guarantees that Android does not freeze the CPU or pause background sync when the screen is turned off.
     */
    @Synchronized
    fun startContinuousKeepAlive(context: Context) {
        try {
            if (continuousWakeLock == null) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                continuousWakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "scanner:ContinuousKeepAliveWakeLock"
                ).apply {
                    setReferenceCounted(false)
                }
            }
            if (continuousWakeLock?.isHeld == false) {
                continuousWakeLock?.acquire()
                Log.d(TAG, "Acquired continuous PARTIAL_WAKE_LOCK (keeps CPU alive with screen off).")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire continuous WakeLock: ${e.message}")
        }
    }

    @Synchronized
    fun stopContinuousKeepAlive() {
        try {
            if (continuousWakeLock?.isHeld == true) {
                continuousWakeLock?.release()
                Log.d(TAG, "Released continuous PARTIAL_WAKE_LOCK.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release continuous WakeLock: ${e.message}")
        }
    }

    /**
     * Schedules a persistent silent alarm clock wake-up.
     * Uses the exact same AlarmClock hardware mechanism as an Android Alarm Clock app,
     * but wakes up completely silently in the background with zero sound, vibration, or popup.
     */
    fun scheduleSilentAlarm(context: Context, triggerAtMillis: Long? = null) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, MediaSyncWatchdogReceiver::class.java).apply {
                action = ACTION_WATCHDOG_WAKE
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)

            val wallClockTime = triggerAtMillis ?: (System.currentTimeMillis() + INTERVAL_MILLIS)
            val elapsedDelay = wallClockTime - System.currentTimeMillis()
            val elapsedTrigger = SystemClock.elapsedRealtime() + if (elapsedDelay > 0) elapsedDelay else INTERVAL_MILLIS

            // 1. Alarm Clock API: Exact same mechanism used by Google Clock and Alarm apps.
            // Bypasses Doze mode, bypasses OEM task killers, wakes up CPU silently with zero sound or UI,
            // and grants the official Android 12+ exemption to start background sync.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    val showPendingIntent = if (launchIntent != null) {
                        PendingIntent.getActivity(context, REQUEST_CODE + 1, launchIntent, flags)
                    } else {
                        pendingIntent
                    }
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(wallClockTime, showPendingIntent)
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                    Log.d(TAG, "Silent alarm wake-up successfully set via setAlarmClock for time: $wallClockTime")
                    return
                } catch (e: Exception) {
                    Log.w(TAG, "setAlarmClock not permitted or failed: ${e.message}, falling back to setExactAndAllowWhileIdle")
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, elapsedTrigger, pendingIntent)
                    } else {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, elapsedTrigger, pendingIntent)
                    }
                } else {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, elapsedTrigger, pendingIntent)
                }
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, elapsedTrigger, pendingIntent)
            }
            Log.d(TAG, "Silent alarm wake-up set via exact alarm for time: $wallClockTime")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule silent alarm: ${e.message}", e)
        }
    }

    /**
     * Alias for scheduleSilentAlarm to maintain backwards compatibility.
     */
    fun scheduleHeartbeat(context: Context) {
        scheduleSilentAlarm(context)
    }

    /**
     * Checks if media read permissions have been granted.
     * Prevents triggering foreground services prematurely during initial permission requests.
     */
    fun hasMediaPermissions(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && android.os.Environment.isExternalStorageManager()) {
                return true
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.READ_MEDIA_IMAGES
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.READ_MEDIA_VIDEO
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            } else {
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.READ_EXTERNAL_STORAGE
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            }
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Ensures that flutter_background_service is alive and running as a Foreground Service.
     */
    fun ensureServiceRunning(context: Context) {
        if (!hasMediaPermissions(context)) {
            Log.d(TAG, "Permissions not yet granted. Skipping ensureServiceRunning to avoid premature service crash.")
            return
        }

        try {
            val pluginClass = Class.forName("id.flutter.flutter_background_service.FlutterBackgroundServicePlugin")
            val field = pluginClass.getDeclaredField("servicePipe")
            field.isAccessible = true
            val pipe = field.get(null)
            if (pipe != null) {
                val hasListenerMethod = pipe.javaClass.getMethod("hasListener")
                val isServiceActive = hasListenerMethod.invoke(pipe) as? Boolean ?: false
                if (isServiceActive) {
                    Log.d(TAG, "BackgroundService is already active and listening. No need to restart.")
                    return
                }
            }
        } catch (_: Exception) {}

        try {
            val serviceClass = Class.forName("id.flutter.flutter_background_service.BackgroundService")
            // Acquire flutter_background_service static wake lock like BootReceiver does
            try {
                val lockMethod = serviceClass.getMethod("getLock", Context::class.java)
                val lock = lockMethod.invoke(null, context) as? PowerManager.WakeLock
                if (lock?.isHeld == false) {
                    lock.acquire(60000L)
                }
            } catch (_: Exception) {}

            val serviceIntent = Intent(context, serviceClass)
            val hasNotification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.POST_NOTIFICATIONS
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            } else {
                true
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && hasNotification) {
                try {
                    context.startForegroundService(serviceIntent)
                } catch (e: Exception) {
                    Log.w(TAG, "startForegroundService deferred: ${e.message}, falling back to startService")
                    try {
                        context.startService(serviceIntent)
                    } catch (_: Exception) {}
                }
            } else {
                try {
                    context.startService(serviceIntent)
                } catch (_: Exception) {}
            }
            Log.d(TAG, "Ensured BackgroundService is started.")
        } catch (e: Exception) {
            Log.e(TAG, "Could not start BackgroundService: ${e.message}")
        }
    }

    /**
     * Ensures the background service is alive and immediately triggers a backup sync cycle in Dart.
     * Retries dispatch in the background if the service's Flutter isolate is still initializing.
     */
    fun triggerSyncNow(context: Context) {
        try {
            ensureServiceRunning(context)
            val data = org.json.JSONObject().apply {
                put("action", "triggerSync")
                put("method", "triggerSync")
                put("args", org.json.JSONObject())
            }
            val pluginClass = Class.forName("id.flutter.flutter_background_service.FlutterBackgroundServicePlugin")
            val field = pluginClass.getDeclaredField("servicePipe")
            field.isAccessible = true
            val pipe = field.get(null)
            if (pipe != null) {
                val hasListenerMethod = pipe.javaClass.getMethod("hasListener")
                val invokeMethod = pipe.javaClass.getMethod("invoke", org.json.JSONObject::class.java)
                val hasListener = hasListenerMethod.invoke(pipe) as? Boolean ?: false

                if (hasListener) {
                    invokeMethod.invoke(pipe, data)
                    Log.d(TAG, "Successfully dispatched triggerSync to BackgroundService.")
                } else {
                    Log.d(TAG, "Service initializing; retrying triggerSync dispatch in background...")
                    Thread {
                        for (i in 1..10) {
                            try {
                                Thread.sleep(1000)
                                val ready = hasListenerMethod.invoke(pipe) as? Boolean ?: false
                                if (ready) {
                                    invokeMethod.invoke(pipe, data)
                                    Log.d(TAG, "Successfully dispatched triggerSync on retry $i.")
                                    break
                                }
                            } catch (_: Exception) {}
                        }
                    }.start()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "triggerSync dispatch note: ${e.message}")
        }
    }

    /**
     * Acquires a temporary partial CPU WakeLock so the phone doesn't sleep while starting/syncing.
     */
    @Synchronized
    fun acquireWakeLock(context: Context, timeoutMs: Long = 60000L) {
        try {
            if (wakeLock == null) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "scanner:SyncWatchdogWakeLock").apply {
                    setReferenceCounted(false)
                }
            }
            wakeLock?.let {
                if (!it.isHeld) {
                    it.acquire(timeoutMs)
                    Log.d(TAG, "Acquired WakeLock for ${timeoutMs}ms")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock: ${e.message}")
        }
    }

    @Synchronized
    fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Released WakeLock")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release WakeLock: ${e.message}")
        }
    }
}

