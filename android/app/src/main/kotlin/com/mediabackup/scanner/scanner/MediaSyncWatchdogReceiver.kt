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

        // 1. Hold WakeLock for up to 60 seconds to allow the service to start and CPU to stay active
        MediaSyncWatchdog.acquireWakeLock(context, 60000L)

        // 2. Ensure the Flutter BackgroundService is running
        MediaSyncWatchdog.ensureServiceRunning(context)

        // 3. Register ContentObserver if not already active
        MediaStoreChangeObserver.register(context)

        // 4. Re-arm the next heartbeat alarm (unbroken chain)
        MediaSyncWatchdog.scheduleHeartbeat(context)
    }
}

