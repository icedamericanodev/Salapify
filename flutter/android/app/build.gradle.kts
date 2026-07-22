plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.icedamericano.salapify"
    // file_picker's flutter_plugin_android_lifecycle requires compileSdk 36, so
    // pin it here rather than the Flutter default (34/35). AGP 9 and Gradle 9
    // support it. targetSdk stays on the Flutter default on purpose: compileSdk
    // only allows newer APIs at build time, it does not opt into new runtime
    // behavior the way a targetSdk bump would.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (v18) uses java.time on older API levels,
        // so the release build needs core library desugaring turned on.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.icedamericano.salapify"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Preview key, committed on purpose so every CI build installs OVER the
        // previous one on the founder's phone (Android requires the same
        // signature to update in place). This is NOT the Play production key;
        // when we set up Play, a separate upload key lives outside the repo.
        create("preview") {
            storeFile = file("preview-keystore.jks")
            storePassword = "salapify-preview"
            keyAlias = "preview"
            keyPassword = "salapify-preview"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("preview")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required by core library desugaring above, for flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
