plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.icedamericano.salapify"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // UNDECIDED, AND THIS VALUE IS THE DANGEROUS ONE. Decision D4.
        //
        // "dev.icedamericano.salapify" is what `flutter create` produced from
        // the org flag, and it is byte for byte the id of the app currently
        // installed on the founder's phone. Building and installing this as it
        // stands REPLACES their working app with an unfinished one.
        //
        // The two options, and why it is the founder's call and not a default:
        //
        //   Same id. The new APK installs over the old one and finds the
        //   encrypted store already there, so the founder's real data is
        //   present on first launch. They lose the old app the moment they
        //   install.
        //
        //   A separate id, for example a ".v3" suffix. v3 sits BESIDE the
        //   daily app and they switch over when they choose. Android sandboxes
        //   storage per application id, so v3 CANNOT read the old store: the
        //   data comes across as a backup file import instead. Safer to trial,
        //   one extra step to carry the data.
        //
        // Nothing in Phase B builds or installs, so either value is harmless
        // today. It stops being harmless at Phase D. Do not ship a build from
        // this file until the line above is a decision rather than a default.
        applicationId = "dev.icedamericano.salapify"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
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
