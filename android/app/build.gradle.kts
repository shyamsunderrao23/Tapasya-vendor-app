import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    id("kotlin-android")

    // The Flutter Gradle Plugin must be applied after
    // the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.tapasya_vendor_app"

    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    buildToolsVersion = "35.0.0"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    /*
     * RELEASE SIGNING
     *
     * Only configure the release keystore when key.properties
     * exists and contains all required values.
     *
     * This prevents:
     * "null cannot be cast to non-null type kotlin.String"
     */
    signingConfigs {
        if (keystorePropertiesFile.exists()) {

            val keyAliasValue =
                keystoreProperties.getProperty("keyAlias")

            val keyPasswordValue =
                keystoreProperties.getProperty("keyPassword")

            val storeFileValue =
                keystoreProperties.getProperty("storeFile")

            val storePasswordValue =
                keystoreProperties.getProperty("storePassword")

            if (
                !keyAliasValue.isNullOrBlank() &&
                !keyPasswordValue.isNullOrBlank() &&
                !storeFileValue.isNullOrBlank() &&
                !storePasswordValue.isNullOrBlank()
            ) {
                create("release") {
                    keyAlias = keyAliasValue
                    keyPassword = keyPasswordValue
                    storeFile = rootProject.file(storeFileValue)
                    storePassword = storePasswordValue
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.tapasya.vendor"

        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            /*
             * Use release signing only if it was successfully created.
             *
             * Otherwise Gradle can still build the project without
             * crashing because of a missing key.properties value.
             */
            if (signingConfigs.names.contains("release")) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )

    implementation(
        "androidx.core:core-ktx:1.15.0"
    )

    implementation(
        "com.google.firebase:firebase-messaging:24.1.0"
    )
}

kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}