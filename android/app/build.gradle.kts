plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jajanku.app"
    compileSdk = 37 // <-- Ubah dari flutter.compileSdkVersion menjadi 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jajanku.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 37 // <-- Ubah dari flutter.targetSdkVersion menjadi 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")

        isMinifyEnabled = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}}
