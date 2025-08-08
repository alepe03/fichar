plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.trvtrivalle.fichar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // --- Asegúrate de tener la opción de desugaring activada ---
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true   // ESTA ES LA LÍNEA CLAVE
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.trvtrivalle.fichar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Necesario para desugaring (requerido por qr_code_scanner)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.0")
}

flutter {
    source = "../.."
}
