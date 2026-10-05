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
        // REQUIRED BY flutter_local_notifications, from version 10 onward, and
        // this is a build failure rather than a warning if it is missing. The
        // plugin uses newer Java time APIs and relies on desugaring to run
        // them on older Android versions. Read from the plugin's own README at
        // the pinned version, not remembered.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.icedamericano.salapify3"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Desugaring plus the plugin's own dependencies push the method count
        // toward the 65k limit on older build paths. The plugin's README asks
        // for this alongside desugaring.
        multiDexEnabled = true
    }

    signingConfigs {
        // THE PREVIEW KEY, COMMITTED ON PURPOSE. It is not a secret and it is
        // not the Play production key.
        //
        // Android will only install an update over an existing app when both
        // carry the SAME signature. A debug keystore, which is what `release`
        // used until 2026-10-05, is GENERATED PER MACHINE: Gradle makes one at
        // ~/.android/debug.keystore the first time it needs one. A CI runner is
        // a fresh machine every run, so two base APKs built from two runs are
        // signed by two different keys, and the second one cannot install over
        // the first. Android's only route out of that is uninstall, which
        // deletes the app's whole data directory.
        //
        // The shape of the failure is why this was urgent rather than tidy
        // work: the FIRST install succeeds and looks perfect. The bill arrives
        // at the first native change, which is the first time a new base APK is
        // needed, and by then there are weeks of records to lose. Retrofitting
        // a key later is itself an uninstall, so it cannot be done after the
        // fact. It had to land before anything installable reached a phone.
        //
        // Committing the key is what makes every build install over the last
        // one. Anyone who has this file can sign an APK that Android would
        // accept as an update to a Salapify 3 PREVIEW build, which is why it
        // must never be the key a Play Store release is signed with.
        //
        // Fingerprint, so a build can be checked against the intended key:
        //   SHA256 3D:2B:C8:6C:0D:25:24:EB:68:4E:5F:66:AC:FB:13:A5:
        //          11:64:6F:13:C4:EC:12:33:28:51:4C:E7:BC:E7:51:12
        //
        // Generated fresh for Salapify 3 rather than copied from
        // archive/salapify-2-flutter/android/app/preview-keystore.jks, which is
        // a different key (SHA256 7E:F5:EE:...). Reusing that one would have
        // cost nothing technically and invited the next reader to believe the
        // two apps are the same app. They are not: this is applicationId
        // dev.icedamericano.salapify3 and that is dev.icedamericano.salapify.
        create("preview") {
            storeFile = file("preview-keystore.jks")
            storePassword = "salapify3-preview"
            keyAlias = "preview"
            keyPassword = "salapify3-preview"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("preview")
        }
    }
}

// BEFORE THE FIRST PLAY STORE UPLOAD, and not before, this file needs a
// second signing config and a way to choose between the two. It is written
// here rather than built now because Play is a separate later track and half
// a production track is worse than none.
//
// What it will need, and the archived app at
// archive/salapify-2-flutter/android/app/build.gradle.kts lines 44 to 96 is a
// working example of all of it:
//
//  1. An `upload` signingConfig whose store file, passwords and alias come
//     ONLY from environment variables set by CI, never from this file and
//     never from the repository.
//  2. NO FALLBACK from `upload` to `preview`. If the upload key is missing the
//     build must fail loudly at signing. A fallback means a misconfigured
//     secret silently ships a preview-signed artifact to the store, and the
//     key a Play app is first signed with is the key it is married to.
//  3. Product flavors, so the two are separate artifacts that cannot be
//     confused, with `release` dropping its signingConfig so the flavor
//     decides.
//
// UNTIL THEN, `flutter build appbundle --release` produces a PREVIEW SIGNED
// bundle. That is correct for sideloading and wrong for the store, so do not
// upload one.

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // The other half of isCoreLibraryDesugaringEnabled. Enabling the flag
    // without this dependency fails the build with a message that does not
    // name either of them.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
