import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase Cloud Messaging, applied only when its credentials are here.
//
// The google-services plugin fails the build outright if google-services.json
// is missing, which would mean nobody could build the app at all until they
// had set up a Firebase project. Push is worth having; it is not worth making
// it impossible to compile without. Absent the file, firebase_core simply
// fails to initialise at runtime and PushService turns itself off — see
// docs/PUSH.md.
val hasFirebaseConfig = file("google-services.json").exists()
if (hasFirebaseConfig) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "Omnia: android/app/google-services.json not found — building without " +
            "push notifications. See docs/PUSH.md.",
    )
}

// Release upload-signing config, loaded from `android/key.properties`
// (gitignored — never committed). When the file is absent (e.g. a fresh
// clone, CI without secrets, or a local debug build) the release build falls
// back to debug signing so the project still assembles; that fallback AAB is
// NOT publishable to Google Play. See RELEASE.md for how to create the
// upload keystore and key.properties.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.omnia.wallet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications calls java.time APIs that only exist on
        // API 26+, and the app supports older devices. Desugaring backports
        // them into the APK; without it the build fails at
        // :app:checkReleaseAarMetadata, before anything is even compiled.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.omnia.wallet"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Real upload signing when a keystore is configured; otherwise
            // fall back to debug so the project still builds (that artifact is
            // not publishable — see the note above).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Pinned, not a range: flutter_local_notifications 18 requires at least
    // 2.1.4, and a lower version resolved transitively fails the same
    // AAR-metadata check that desugaring is being enabled for.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
