// The toolchain this project is pinned to.
//
// These MUST stay in step with the plugin versions in `settings.gradle.kts`.
// They are repeated rather than shared because a settings `plugins {}` block
// cannot take a value computed in a project script — and if they ever drift,
// the force below would quietly pin plugin subprojects to a toolchain the app
// itself no longer uses.
val agpVersion = "8.11.1"
val kotlinVersion = "2.2.20"

allprojects {
    repositories {
        google()
        // Google's own GCS mirror of Maven Central. It is markedly faster and
        // more reliable than repo1.maven.org from some networks, and listing
        // it first means Maven Central is only reached for the rare artifact
        // the mirror does not carry. Declared here as well as in
        // settings.gradle.kts because plugin subprojects contribute their own
        // `repositories` block.
        maven(url = "https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
    }

    // Several Flutter plugins — share_plus among them, in every release
    // including the newest — still use the legacy `buildscript {}` style and
    // declare their *own* Android Gradle Plugin and Kotlin versions:
    //
    //     buildscript {
    //         dependencies { classpath 'com.android.tools.build:gradle:8.11.1' }
    //     }
    //
    // Left alone, that makes Gradle download a second, complete AGP toolchain
    // that nothing else in the build uses — a few hundred megabytes from
    // dl.google.com on the first build, which is a long time to hold a socket
    // open on a slow link and the reason `flutter build apk` failed with
    // "Read timed out" fetching com.android.tools.analytics-library:protos.
    // Two AGP versions on one classpath is also a known source of bare
    // NullPointerExceptions during project evaluation.
    //
    // Forcing the plugin's script classpath onto the versions the app already
    // resolves means there is nothing extra to download and one AGP in play.
    // `allprojects` runs while the root project is evaluated, which is before
    // any plugin subproject's script is compiled, so the strategy is in place
    // by the time that classpath is resolved.
    buildscript.configurations
        .matching { it.name == "classpath" }
        .configureEach {
            resolutionStrategy {
                force("com.android.tools.build:gradle:$agpVersion")
                force("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
            }
        }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
