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

        // Immediately notify foreground UI if open and trigger background service.
        // The sync cycle owns a short, timeout-bound wake lock.
        MainActivity.notifyMediaChange()
        MediaSyncWatchdog.triggerSyncNow(context)

        // 3. Register ContentObserver if not already active
        MediaStoreChangeObserver.register(context)

        // Ensure JobScheduler content URI trigger is active for new media.
        MediaSyncJobService.scheduleMediaChangeJob(context)
        MediaSyncJobService.schedulePeriodicWakeJob(context)
    }
}

