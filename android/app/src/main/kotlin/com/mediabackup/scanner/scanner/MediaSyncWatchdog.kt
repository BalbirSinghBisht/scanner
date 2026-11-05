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

    /**
     * Schedules a persistent repeating wakeup alarm with the highest priority available.
     * Uses setAlarmClock or setExactAndAllowWhileIdle to punch through Android Doze mode.
     */
    fun scheduleHeartbeat(context: Context) {
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

            val triggerAtElapsed = SystemClock.elapsedRealtime() + INTERVAL_MILLIS
            val triggerAtWallClock = System.currentTimeMillis() + INTERVAL_MILLIS

            // 1. Try setAlarmClock first (highest priority, ignores Doze, standard for backup/alarm apps)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    val showPendingIntent = if (launchIntent != null) {
                        PendingIntent.getActivity(context, REQUEST_CODE + 1, launchIntent, flags)
                    } else {
                        pendingIntent
                    }
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtWallClock, showPendingIntent)
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                    Log.d(TAG, "Watchdog scheduled via setAlarmClock (+10m)")
                    return
                } catch (e: Exception) {
                    Log.w(TAG, "setAlarmClock not permitted or failed: ${e.message}, falling back...")
                }

                // 2. Fallback to exact/allowWhileIdle
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
                        Log.d(TAG, "Watchdog scheduled via setExactAndAllowWhileIdle (+10m)")
                    } else {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
                        Log.d(TAG, "Watchdog scheduled via setAndAllowWhileIdle (+10m)")
                    }
                } else {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
                    Log.d(TAG, "Watchdog scheduled via setExactAndAllowWhileIdle (+10m)")
                }
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
                Log.d(TAG, "Watchdog scheduled via set (+10m)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule watchdog heartbeat: ${e.message}", e)
        }
    }

    /**
     * Ensures that flutter_background_service is alive and running as a Foreground Service.
     */
    fun ensureServiceRunning(context: Context) {
        try {
            val serviceIntent = Intent().apply {
                component = ComponentName(context.packageName, "id.flutter.flutter_background_service.BackgroundService")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Ensured BackgroundService is started.")
        } catch (e: Exception) {
            Log.e(TAG, "Could not start BackgroundService: ${e.message}")
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

