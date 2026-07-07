pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        // GCS mirror of Maven Central — see the note in build.gradle.kts.
        maven(url = "https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned to the stable Android Gradle Plugin / Kotlin line. AGP 9.x is
    // still experimental and its DSL breaks on many machines. 8.9.1 is the
    // minimum required by supabase_flutter's androidx dependencies
    // (androidx.browser 1.9.0 / androidx.core 1.17.0) and runs on the
    // Gradle 8.11.1 wrapper this project already uses.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
}

include(":app")
