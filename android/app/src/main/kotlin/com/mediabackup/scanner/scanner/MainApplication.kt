package com.mediabackup.scanner.scanner

import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        MediaSyncWatchdog.startContinuousKeepAlive(this)
        MediaSyncWatchdog.scheduleHeartbeat(this)
        MediaStoreChangeObserver.register(this)
    }
}

