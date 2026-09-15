plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.icedamericano.salapify"
    // PINNED, not `flutter.compileSdkVersion`, because file_picker's
    // flutter_plugin_android_lifecycle requires 36 and the Flutter default is
    // lower. Adding file_picker without this turns the first build after the
    // pull into "BUILD FAILED ... Gradle task assembleDebug failed with exit
    // code 1", which is what the founder hit on their emulator.
    //
    // compileSdk only allows newer APIs at BUILD time. It does not opt the app
    // into new runtime behaviour the way targetSdk does, so raising it is not
    // a behaviour change and needs no review of platform changes.
    //
    // The shipped app in flutter/ already carries this exact pin, for this
    // exact package, with this exact reasoning. It was hit there first and the
    // reason was written down, which is the only thing that made it a two
    // minute fix here instead of an afternoon.
    compileSdk = 36
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
        // ANSWERED by the founder on 2026-09-13: BESIDE IT. See D4 in
        // docs/revamp/07-decisions.md.
        //
        // So this is no longer flutter create's default, it is a decision, and
        // the id below deliberately differs from the shipped app's
        // "dev.icedamericano.salapify" by one character group. Two consequences
        // that are easy to forget and expensive to remember late:
        //
        //   1. v3 starts EMPTY on the founder's phone, always. Android sandboxes
        //      storage per application id, so v3 cannot see the old store even
        //      though both apps are on the same device. Backup then Restore is
        //      the only bridge, which promotes restore from a Phase 4 fallback
        //      to something on the critical path.
        //   2. versionCode restarts at 1 (pubspec 1.0.0+1). It was +21 only to
        //      out-rank the old app's +20 so a build would install over it, and
        //      that is no longer the plan. The two version lines now have
        //      nothing to do with each other.
        //
        // The launcher label is "Salapify 3" in AndroidManifest.xml for the
        // same reason: two icons both reading "Salapify" is a trap.
        applicationId = "dev.icedamericano.salapify3"
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
