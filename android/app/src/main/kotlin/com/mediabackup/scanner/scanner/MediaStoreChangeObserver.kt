package com.mediabackup.scanner.scanner

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log

class MediaStoreChangeObserver(private val context: Context, handler: Handler) : ContentObserver(handler) {
    companion object {
        private const val TAG = "MediaStoreObserver"
        private var isRegistered = false

        fun register(context: Context) {
            if (isRegistered) return
            try {
                val observer = MediaStoreChangeObserver(context.applicationContext, Handler(Looper.getMainLooper()))
                val resolver = context.contentResolver
                resolver.registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, observer)
                resolver.registerContentObserver(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, observer)
                isRegistered = true
                Log.d(TAG, "Successfully registered MediaStore ContentObserver for Images and Videos")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register MediaStore ContentObserver: ${e.message}")
            }
        }
    }

    private var lastTriggerTime = 0L

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)
        if (!MediaSyncWatchdog.hasMediaPermissions(context)) {
            return
        }
        val now = System.currentTimeMillis()
        // Debounce to prevent multiple fires within 5 seconds for rapid photo taking
        if (now - lastTriggerTime < 5000L) return
        lastTriggerTime = now

        Log.d(TAG, "Detected new media change via MediaStore: $uri. Waking up background sync immediately...")
        MediaSyncWatchdog.acquireWakeLock(context, 120000L)
        MediaSyncWatchdog.triggerSyncNow(context)
        MediaSyncWatchdog.scheduleSilentAlarm(context)
    }
}

