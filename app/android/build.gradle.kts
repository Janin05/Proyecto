// android/build.gradle.kts  (nivel proyecto)

// Importante: NO declares buildscript{}, allprojects{} ni repositories{} aquí.
// Los repos y plugins ya están configurados en settings.gradle.kts.

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app" // TODO: pon tu paquete real
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.app" // TODO: pon tu applicationId real
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Si tienes firma, agrega signingConfigs aquí.
        }
    }
}

dependencies {
    // Kotlin BOM (opcional pero recomendado)
    implementation(platform("org.jetbrains.kotlin:kotlin-bom"))
}
android {
    namespace = "com.tuempresa.tuapp"      // ← tu paquete
    …
    defaultConfig {
        applicationId = "com.tuempresa.tuapp"  // ← el mismo
        …
    }
}
