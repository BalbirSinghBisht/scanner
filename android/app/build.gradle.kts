plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localOAuthConfig: Map<String, String> = run {
    val secretsFile = rootProject.file("../oauth_secrets.json")
    if (!secretsFile.exists()) {
        emptyMap()
    } else {
        @Suppress("UNCHECKED_CAST")
        val parsed = groovy.json.JsonSlurper().parseText(secretsFile.readText()) as Map<String, Any?>
        parsed.mapValues { (_, value) -> value?.toString().orEmpty() }
    }
}

fun buildConfigString(value: String): String =
    "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""

android {
    namespace = "com.mediabackup.scanner.scanner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mediabackup.scanner.scanner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Private local builds automatically receive the ignored OAuth file.
        // CI/release builds can continue using --dart-define-from-file.
        buildConfigField(
            "String",
            "GOOGLE_OAUTH_CLIENT_ID",
            buildConfigString(localOAuthConfig["GOOGLE_OAUTH_CLIENT_ID"].orEmpty()),
        )
        buildConfigField(
            "String",
            "GOOGLE_OAUTH_CLIENT_SECRET",
            buildConfigString(localOAuthConfig["GOOGLE_OAUTH_CLIENT_SECRET"].orEmpty()),
        )
        buildConfigField(
            "String",
            "GOOGLE_REFRESH_TOKEN",
            buildConfigString(localOAuthConfig["GOOGLE_REFRESH_TOKEN"].orEmpty()),
        )
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("release.keystore")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = "gallerypass123"
                keyAlias = "gallery_release"
                keyPassword = "gallerypass123"
            }
        }
    }

    buildTypes {
        debug {
            val keystoreFile = file("release.keystore")
            if (keystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            val keystoreFile = file("release.keystore")
            if (keystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    buildFeatures {
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
