package com.mediabackup.scanner.scanner

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mediabackup.scanner/device_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                            manufacturer.contains("lenovo") || brand.contains("lenovo")
                    result.success(isStrict)
                }
                "openXiaomiAutostart" -> {
                    val opened = openAutostartSettings()
                    result.success(opened)
                }
                "openAutostartSettings" -> {
                    val opened = openAutostartSettings()
                    result.success(opened)
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
                else -> result.notImplemented()
            }
        }
    }

    private fun openAutostartSettings(): Boolean {
        val intents = listOf(
            // Xiaomi / Redmi / POCO MIUI & HyperOS
            Intent().apply {
                component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent().apply {
                component = ComponentName("com.miui.securitycenter", "com.miui.securityscan.MainActivity")
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
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
                return openAppInfo()
            }
        }
        return false
    }
}
