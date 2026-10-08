import groovy.json.JsonSlurper
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val config = rootProject.file("key.properties")
    if (config.exists()) config.inputStream().use { load(it) }
}
val devFirebaseFile = file("src/dev/google-services.json")
val prodFirebaseFile = file("src/prod/google-services.json")

android {
    namespace = "com.jajanku.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.jajanku.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storePassword = keystoreProperties.getProperty("storePassword")
            storeFile = keystoreProperties.getProperty("storeFile")
                ?.takeIf { it.isNotBlank() }?.let { rootProject.file(it) }
        }
    }
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            signingConfig = signingConfigs.getByName("debug")
        }
        create("prod") {
            dimension = "environment"
            signingConfig = signingConfigs.getByName("release")
        }
    }
    buildTypes {
        release {
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
    flutter { source = "../.." }
}

// Dev can run locally as Guest until its Firebase project is configured.
// No root-level Firebase config may be used as a fallback for dev.
tasks.configureEach {
    if (name.startsWith("processDev") && name.endsWith("GoogleServices")) {
        onlyIf { devFirebaseFile.exists() }
        doFirst {
            fun projectId(config: File): String {
                val json = JsonSlurper().parse(config) as Map<*, *>
                return (json["project_info"] as Map<*, *>)["project_id"] as String
            }
            check(projectId(devFirebaseFile) != projectId(prodFirebaseFile)) {
                "Firebase dev harus menggunakan project berbeda dari prod. Lihat docs/environments.md."
            }
        }
    }
    if (name == "preProdReleaseBuild") {
        doFirst {
            val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
            check(missing.isEmpty()) {
                "Signing prod belum siap. Isi android/key.properties: ${missing.joinToString()}. Lihat docs/environments.md."
            }
            check(rootProject.file(keystoreProperties.getProperty("storeFile")).isFile) {
                "Upload keystore tidak ditemukan. Periksa storeFile di android/key.properties."
            }
        }
    }
}

dependencies { testImplementation("junit:junit:4.13.2") }
