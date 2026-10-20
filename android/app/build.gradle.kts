// build.gradle.kts для Audio Converter
// compileSdk = 35 (требование ffmpeg_kit_flutter_new)
// minSdk = 24 (Android 7.0+)

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Получаем версию Flutter из local.properties (до блока android)
val flutterVersionCode: String by project
val flutterVersionName: String by project

android {
    namespace = "com.example.audio_converter"
    compileSdk = 35  // ЯВНО указано 35 — требует ffmpeg_kit_flutter_new
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.audio_converter"
        minSdk = 24  // ЯВНО указано 24 — требует ffmpeg_kit_flutter_new
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
