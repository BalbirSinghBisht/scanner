package com.mediabackup.scanner.scanner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()

        // 1. Ensure foreground service notification channel exists natively before any service starts
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val channel = NotificationChannel(
                    "media_backup_service_channel",
                    "Gallery",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Gallery service"
                    setShowBadge(false)
                    enableVibration(false)
                }
                val manager = getSystemService(NotificationManager::class.java)
                manager?.createNotificationChannel(channel)
            } catch (_: Exception) {}
        }

        // 2. Only register background job & media observers if media permissions are already granted.
        // Prevents premature foreground service crashes during initial permission granting.
        if (MediaSyncWatchdog.hasMediaPermissions(this)) {
            MediaSyncWatchdog.startContinuousKeepAlive(this)
            MediaSyncWatchdog.scheduleHeartbeat(this)
            MediaStoreChangeObserver.register(this)
            MediaSyncJobService.scheduleMediaChangeJob(this)
            MediaSyncJobService.schedulePeriodicWakeJob(this)
        }
    }
}

