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
    // still experimental and its DSL breaks on many machines. 8.11.1 is
    // required by the current Flutter stable toolchain and runs on the
    // Gradle 8.14.1 wrapper this project uses.
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
    // Firebase. Declared but not applied here — app/build.gradle.kts applies
    // it only when google-services.json is present, so a clone without
    // Firebase credentials still builds.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
