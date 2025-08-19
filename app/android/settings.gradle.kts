
pluginManagement {
   
    val properties = java.util.Properties()
    val localProps = file("local.properties")
    if (localProps.exists()) {
        localProps.inputStream().use { properties.load(it) }
    }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "app"
include(":app")
// android/settings.gradle.kts  (KOTLIN DSL)

pluginManagement {
    // Lee flutter.sdk de local.properties
    val properties = java.util.Properties()
    val localProps = file("local.properties")
    if (localProps.exists()) {
        localProps.inputStream().use { properties.load(it) }
    }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // >>> IMPORTANTE: declara aquí versiones de AGP y Kotlin (apply false!)
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "app"
include(":app")
