package com.mediabackup.scanner.scanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MediaSyncWatchdogReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MediaSyncReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Received broadcast action: $action")

        // 1. Maintain CPU keep-alive so phone does not sleep while sync runs
        MediaSyncWatchdog.startContinuousKeepAlive(context)

        // 2. Immediately trigger the backup sync cycle in BackgroundService
        MediaSyncWatchdog.triggerSyncNow(context)

        // 3. Register ContentObserver if not already active
        MediaStoreChangeObserver.register(context)

        // 4. Re-arm the next silent alarm clock (unbroken alarm chain)
        MediaSyncWatchdog.scheduleSilentAlarm(context)

        // 5. Ensure JobScheduler content URI trigger is active for new media
        MediaSyncJobService.scheduleMediaChangeJob(context)
        MediaSyncJobService.schedulePeriodicWakeJob(context)
    }
}

