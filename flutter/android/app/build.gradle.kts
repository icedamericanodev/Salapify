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

flutter {
    source = "../.."
}
