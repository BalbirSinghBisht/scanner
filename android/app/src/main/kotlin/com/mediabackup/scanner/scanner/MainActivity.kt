package com.mediabackup.scanner.scanner

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mediabackup.scanner/device_settings"
    private val thumbnailExecutor = java.util.concurrent.Executors.newFixedThreadPool(2)

    companion object {
        private const val TAG = "MainActivity"
        private var activeChannel: MethodChannel? = null

        fun notifyMediaChange() {
            try {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    try {
                        activeChannel?.invokeMethod("onMediaChanged", null)
                        Log.d(TAG, "Successfully notified Flutter UI isolate of onMediaChanged")
                    } catch (e: Exception) {
                        Log.d(TAG, "activeChannel invokeMethod notice: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Could not post onMediaChanged to main looper: ${e.message}")
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            MediaSyncWatchdog.startContinuousKeepAlive(this)
            MediaSyncWatchdog.scheduleHeartbeat(this)
            MediaStoreChangeObserver.register(this)
            MediaSyncJobService.scheduleMediaChangeJob(this)
            MediaSyncJobService.schedulePeriodicWakeJob(this)
        } catch (e: Exception) {
            Log.e(TAG, "Watchdog startup notice: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        activeChannel = null
        // Ensure alarm and service remain scheduled when activity closes
        MediaSyncWatchdog.scheduleHeartbeat(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isXiaomiDevice" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val brand = Build.BRAND.lowercase()
                    val isXiaomi = manufacturer.contains("xiaomi") || brand.contains("xiaomi") ||
                            manufacturer.contains("redmi") || brand.contains("redmi") ||
                            manufacturer.contains("poco") || brand.contains("poco")
                    result.success(isXiaomi)
                }
                "isStrictOEMDevice" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val brand = Build.BRAND.lowercase()
                    val isStrict = manufacturer.contains("xiaomi") || brand.contains("xiaomi") ||
                            manufacturer.contains("redmi") || brand.contains("redmi") ||
                            manufacturer.contains("poco") || brand.contains("poco") ||
                            manufacturer.contains("realme") || brand.contains("realme") ||
                            manufacturer.contains("oppo") || brand.contains("oppo") ||
                            manufacturer.contains("oneplus") || brand.contains("oneplus") ||
                            manufacturer.contains("vivo") || brand.contains("vivo") ||
                            manufacturer.contains("iqoo") || brand.contains("iqoo") ||
                            manufacturer.contains("huawei") || brand.contains("huawei") ||
                            manufacturer.contains("honor") || brand.contains("honor") ||
                            manufacturer.contains("motorola") || brand.contains("motorola") ||
                            manufacturer.contains("moto") || brand.contains("moto") ||
                            manufacturer.contains("samsung") || brand.contains("samsung") ||
                            manufacturer.contains("lenovo") || brand.contains("lenovo")
                    result.success(isStrict)
                }
                "getDeviceManufacturer" -> {
                    result.success(Build.MANUFACTURER)
                }
                "getDeviceBrand" -> {
                    result.success(Build.BRAND)
                }
                "getDeviceModel" -> {
                    result.success(Build.MODEL)
                }
                "openBatteryOptimizationSettings" -> {
                    val opened = openBatteryOptimizationSettings()
                    result.success(opened)
                }
                "openXiaomiAutostart" -> {
                    val opened = openAutostartSettings()
                    result.success(opened)
                }
                "openAutostartSettings" -> {
                    val opened = openAutostartSettings()
                    result.success(opened)
                }
                "isAutostartEnabled" -> {
                    val enabled = isXiaomiAutostartEnabled()
                    result.success(enabled)
                }
                "areNotificationsEnabled" -> {
                    val nm = androidx.core.app.NotificationManagerCompat.from(this)
                    result.success(nm.areNotificationsEnabled())
                }
                "isAllFilesAccessGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(android.os.Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "requestAllFilesAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(openAppInfo())
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openXiaomiBatterySaverSettings" -> {
                    val intent = Intent().apply {
                        component = ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
                        putExtra("package_name", packageName)
                        putExtra("package_label", "Gallery")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    try {
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(openAppInfo())
                        }
                    } catch (_: Exception) {
                        result.success(openAppInfo())
                    }
                }
                "deleteMediaFile" -> {
                    val path = call.argument<String>("path")
                    val id = call.argument<String>("id")
                    var deleted = false

                    // 1. Delete file directly from filesystem if possible
                    if (path != null) {
                        try {
                            val file = java.io.File(path)
                            if (file.exists()) {
                                deleted = file.delete()
                            }
                        } catch (_: Exception) {}
                    }

                    // 2. Delete entry from MediaStore ContentResolver
                    try {
                        val cr = contentResolver
                        val numericId = id?.toLongOrNull()
                        if (numericId != null && numericId > 0) {
                            try {
                                val imgUri = android.content.ContentUris.withAppendedId(
                                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI, numericId
                                )
                                if (cr.delete(imgUri, null, null) > 0) {
                                    deleted = true
                                }
                            } catch (_: Exception) {}

                            try {
                                val vidUri = android.content.ContentUris.withAppendedId(
                                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI, numericId
                                )
                                if (cr.delete(vidUri, null, null) > 0) {
                                    deleted = true
                                }
                            } catch (_: Exception) {}
                        }

                        if (path != null) {
                            try {
                                val filesUri = MediaStore.Files.getContentUri("external")
                                val count = cr.delete(filesUri, "${MediaStore.MediaColumns.DATA} = ?", arrayOf(path))
                                if (count > 0) deleted = true
                            } catch (_: Exception) {}
                        }
                    } catch (_: Exception) {}

                    // 3. Inform Android MediaScanner that file was removed
                    if (path != null) {
                        try {
                            android.media.MediaScannerConnection.scanFile(
                                context,
                                arrayOf(path),
                                null,
                                null
                            )
                        } catch (_: Exception) {}
                    }

                    result.success(deleted)
                }
                "openAppInfoSettings" -> {
                    val opened = openAppInfo()
                    result.success(opened)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && pm != null) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    val requested = requestIgnoreBattery()
                    result.success(requested)
                }
                "shareFile" -> {
                    val path = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType") ?: "image/*"
                    if (path != null) {
                        try {
                            val file = java.io.File(path)
                            if (file.exists()) {
                                val uri = androidx.core.content.FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    file
                                )
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = mimeType
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                val chooser = Intent.createChooser(intent, "Share").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(chooser)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "File not found: $path", null)
                            }
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "shareMultipleFiles" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (paths.isNotEmpty()) {
                        try {
                            val uris = java.util.ArrayList<Uri>()
                            for (p in paths) {
                                val file = java.io.File(p)
                                if (file.exists()) {
                                    val uri = androidx.core.content.FileProvider.getUriForFile(
                                        context,
                                        "${context.packageName}.fileprovider",
                                        file
                                    )
                                    uris.add(uri)
                                }
                            }
                            if (uris.isNotEmpty()) {
                                val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                    type = mimeType
                                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                val chooser = Intent.createChooser(intent, "Share Media").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(chooser)
                                result.success(true)
                            } else {
                                result.error("FILES_NOT_FOUND", "No files found on disk", null)
                            }
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATHS", "Paths list is empty", null)
                    }
                }
                "startWatchdog" -> {
                    MediaSyncWatchdog.startContinuousKeepAlive(this)
                    MediaSyncWatchdog.scheduleSilentAlarm(this)
                    MediaStoreChangeObserver.register(this)
                    MediaSyncJobService.scheduleMediaChangeJob(this)
                    MediaSyncJobService.schedulePeriodicWakeJob(this)
                    result.success(true)
                }
                "scheduleSilentAlarm" -> {
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong()
                    MediaSyncWatchdog.scheduleSilentAlarm(this, triggerAtMillis)
                    result.success(true)
                }
                "acquireWakeLock" -> {
                    MediaSyncWatchdog.acquireWakeLock(this, 120000L)
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    MediaSyncWatchdog.releaseWakeLock()
                    result.success(true)
                }
                "startContinuousKeepAlive" -> {
                    MediaSyncWatchdog.startContinuousKeepAlive(this)
                    result.success(true)
                }
                "stopContinuousKeepAlive" -> {
                    MediaSyncWatchdog.stopContinuousKeepAlive()
                    result.success(true)
                }
                "trimVideo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
                    val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L
                    val muteAudio = call.argument<Boolean>("muteAudio") ?: false

                    if (inputPath == null || outputPath == null || endMs <= startMs) {
                        result.error("INVALID_ARGS", "Invalid arguments for video trim", null)
                    } else {
                        // Run trimming in background thread to keep UI smooth
                        Thread {
                            try {
                                val success = VideoTrimmerHelper.trim(
                                    inputPath = inputPath,
                                    outputPath = outputPath,
                                    startMs = startMs,
                                    endMs = endMs,
                                    muteAudio = muteAudio
                                )
                                runOnUiThread {
                                    if (success) {
                                        // Notify Android media scanner so it is indexed
                                        try {
                                            android.media.MediaScannerConnection.scanFile(
                                                context,
                                                arrayOf(outputPath),
                                                arrayOf("video/mp4"),
                                                null
                                            )
                                        } catch (_: Exception) {}
                                        result.success(outputPath)
                                    } else {
                                        result.error("TRIM_FAILED", "Video trimming failed", null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("TRIM_EXCEPTION", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "scanMediaFile" -> {
                    val path = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType")
                    if (path != null) {
                        try {
                            android.media.MediaScannerConnection.scanFile(
                                context,
                                arrayOf(path),
                                if (mimeType != null) arrayOf(mimeType) else null
                            ) { scannedPath, uri ->
                                Log.d("MainActivity", "Scanned media file into MediaStore: $scannedPath -> $uri")
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "extractVideoFrames" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
                    val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L
                    val maxFrames = (call.argument<Number>("maxFrames"))?.toInt() ?: 12

                    if (inputPath == null || endMs <= startMs) {
                        result.error("INVALID_ARGS", "Invalid arguments for frame extraction", null)
                    } else {
                        Thread {
                            try {
                                val retriever = android.media.MediaMetadataRetriever()
                                retriever.setDataSource(inputPath)
                                val durationMs = Math.max(100L, endMs - startMs)
                                val stepMs = Math.max(80L, durationMs / maxFrames)

                                val frameByteList = ArrayList<ByteArray>()
                                var t = startMs
                                while (t <= endMs && frameByteList.size < maxFrames) {
                                    val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                                        retriever.getScaledFrameAtTime(
                                            t * 1000L,
                                            android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                                            360,
                                            360
                                        )
                                    } else {
                                        retriever.getFrameAtTime(
                                            t * 1000L,
                                            android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                                        )
                                    }
                                    if (bitmap != null) {
                                        val stream = java.io.ByteArrayOutputStream()
                                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, stream)
                                        frameByteList.add(stream.toByteArray())
                                        bitmap.recycle()
                                    }
                                    t += stepMs
                                }
                                retriever.release()
                                runOnUiThread {
                                    result.success(frameByteList)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("EXTRACT_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "getVideoThumbnail" -> {
                    val path = call.argument<String>("path")
                    val width = (call.argument<Number>("width"))?.toInt() ?: 280
                    val height = (call.argument<Number>("height"))?.toInt() ?: 280

                    if (path == null) {
                        result.error("INVALID_PATH", "Path is null", null)
                    } else {
                        thumbnailExecutor.execute {
                            var bitmap: android.graphics.Bitmap? = null
                            val file = java.io.File(path)

                            // 1. Try modern Android Q+ ThumbnailUtils
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && file.exists()) {
                                try {
                                    bitmap = android.media.ThumbnailUtils.createVideoThumbnail(
                                        file,
                                        android.util.Size(width, height),
                                        null
                                    )
                                } catch (_: Exception) {}
                            }

                            // 2. Hardware-accelerated MediaMetadataRetriever
                            if (bitmap == null) {
                                var retriever: android.media.MediaMetadataRetriever? = null
                                var fis: java.io.FileInputStream? = null
                                try {
                                    retriever = android.media.MediaMetadataRetriever()
                                    var dataSourceSet = false
                                    try {
                                        retriever.setDataSource(path)
                                        dataSourceSet = true
                                    } catch (_: Exception) {}

                                    if (!dataSourceSet && file.exists()) {
                                        try {
                                            fis = java.io.FileInputStream(file)
                                            retriever.setDataSource(fis.fd, 0, file.length())
                                            dataSourceSet = true
                                        } catch (_: Exception) {}
                                    }

                                    if (dataSourceSet) {
                                        // Attempt A: scaled frame at first frame with OPTION_CLOSEST
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                                            try {
                                                bitmap = retriever.getScaledFrameAtTime(
                                                    0L,
                                                    android.media.MediaMetadataRetriever.OPTION_CLOSEST,
                                                    width,
                                                    height
                                                )
                                            } catch (_: Exception) {}
                                        }

                                        // Attempt B: unscaled frame at first frame with OPTION_CLOSEST
                                        if (bitmap == null) {
                                            try {
                                                bitmap = retriever.getFrameAtTime(
                                                    0L,
                                                    android.media.MediaMetadataRetriever.OPTION_CLOSEST
                                                )
                                            } catch (_: Exception) {}
                                        }

                                        // Attempt C: frame at -1L (auto-detect keyframe)
                                        if (bitmap == null) {
                                            try {
                                                bitmap = retriever.getFrameAtTime(
                                                    -1L,
                                                    android.media.MediaMetadataRetriever.OPTION_CLOSEST
                                                )
                                            } catch (_: Exception) {}
                                        }

                                        // Attempt D: 1-second mark
                                        if (bitmap == null) {
                                            try {
                                                bitmap = retriever.getFrameAtTime(
                                                    1000000L,
                                                    android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                                                )
                                            } catch (_: Exception) {}
                                        }

                                        // Attempt E: parameterless
                                        if (bitmap == null) {
                                            try {
                                                bitmap = retriever.frameAtTime
                                            } catch (_: Exception) {}
                                        }
                                    }
                                } catch (_: Exception) {
                                } finally {
                                    try { fis?.close() } catch (_: Exception) {}
                                    try { retriever?.release() } catch (_: Exception) {}
                                }
                            }

                            // 3. Fallback: legacy ThumbnailUtils
                            if (bitmap == null && file.exists()) {
                                try {
                                    @Suppress("DEPRECATION")
                                    bitmap = android.media.ThumbnailUtils.createVideoThumbnail(
                                        path,
                                        android.provider.MediaStore.Video.Thumbnails.MINI_KIND
                                    )
                                } catch (_: Exception) {}
                            }

                            // Downscale if large bitmap to save memory and avoid transfer lag
                            if (bitmap != null) {
                                try {
                                    if (bitmap.width > width * 1.5 || bitmap.height > height * 1.5) {
                                        val scale = Math.min(width.toFloat() / bitmap.width, height.toFloat() / bitmap.height)
                                        val targetW = Math.max(1, (bitmap.width * scale).toInt())
                                        val targetH = Math.max(1, (bitmap.height * scale).toInt())
                                        val scaled = android.graphics.Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
                                        if (scaled != bitmap) {
                                            bitmap.recycle()
                                            bitmap = scaled
                                        }
                                    }

                                    val stream = java.io.ByteArrayOutputStream()
                                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, stream)
                                    val bytes = stream.toByteArray()
                                    bitmap.recycle()
                                    runOnUiThread { result.success(bytes) }
                                } catch (e: Exception) {
                                    runOnUiThread { result.success(null) }
                                }
                            } else {
                                runOnUiThread { result.success(null) }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openAutostartSettings(): Boolean {
        val intents = listOf(
            // Xiaomi / Redmi / POCO MIUI & HyperOS (Autostart & Battery Saver No Restrictions)
            Intent().apply {
                component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
                putExtra("package_name", packageName)
                putExtra("package_label", "Gallery")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.miui.securitycenter", "com.miui.securityscan.MainActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            // Samsung (OneUI Smart Manager / Device Care & Battery Settings)
            Intent().apply {
                component = ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.ram.AutoRunActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            // Realme / Oppo / OnePlus (Realme UI & ColorOS & OxygenOS)
            Intent().apply {
                component = ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.startup.StartupAppListActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.FakeActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.singlepage.PermissionSinglePageActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.oplus.battery", "com.oplus.powermanager.fuelgaue.PowerUsageModelActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            // Vivo / iQOO (FuntouchOS & OriginOS)
            Intent().apply {
                component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            // Huawei / Honor (EMUI & MagicUI)
            Intent().apply {
                component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )

        for (intent in intents) {
            try {
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }

        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val isMotorola = manufacturer.contains("motorola") || brand.contains("motorola") ||
                manufacturer.contains("moto") || brand.contains("moto") ||
                manufacturer.contains("lenovo") || brand.contains("lenovo")

        if (isMotorola) {
            if (requestIgnoreBattery()) {
                return true
            }
        }

        return openAppInfo()
    }

    private fun isXiaomiAutostartEnabled(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val isXiaomi = manufacturer.contains("xiaomi") || brand.contains("xiaomi") ||
                manufacturer.contains("redmi") || brand.contains("redmi") ||
                manufacturer.contains("poco") || brand.contains("poco")

        if (!isXiaomi) {
            return true
        }

        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val method = appOps.javaClass.getMethod(
                "checkOpNoThrow",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java
            )
            val mode = method.invoke(appOps, 10008, android.os.Process.myUid(), packageName) as Int
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            false
        }
    }

    private fun openAppInfo(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun requestIgnoreBattery(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm != null && pm.isIgnoringBatteryOptimizations(packageName)) {
                // Already unrestricted! Do not reopen battery settings
                return true
            }
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
                return openBatteryOptimizationSettings()
            }
        }
        return false
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
                return openAppInfo()
            }
        }
        return openAppInfo()
    }
}
