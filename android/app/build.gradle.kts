plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

/** Production AdMob — android/admob.properties veya env. Debug bu değerleri kullanmaz. */
val admobProperties = Properties()
val admobPropertiesFile = rootProject.file("admob.properties")
if (admobPropertiesFile.exists()) {
    admobProperties.load(FileInputStream(admobPropertiesFile))
}

fun admobProp(envKey: String, fileKey: String): String =
    (System.getenv(envKey) ?: admobProperties.getProperty(fileKey) ?: "").trim()

val productionAdmobAppId: String = admobProp("ADMOB_APP_ID", "admobAppId")
val productionAdmobBannerId: String = admobProp("ADMOB_BANNER_ID", "admobBannerUnitId")
val productionAdmobInterstitialId: String =
    admobProp("ADMOB_INTERSTITIAL_ID", "admobInterstitialUnitId")

val googleTestAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val googleTestPublisherPrefix = "3940256099942544"

android {
    namespace = "com.tyreest.kira_artisi_hesapla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tyreest.kiraartisi"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Varsayılan: test (debug override yoksa)
        manifestPlaceholders["admobAppId"] = googleTestAdmobAppId
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["admobAppId"] = googleTestAdmobAppId
        }
        release {
            if (!hasReleaseKeystore) {
                throw GradleException(
                    "Release imza için android/key.properties gerekli. " +
                        "Debug imza ile release AAB üretilmez. " +
                        "Adımlar: store/signing.md — tool/create_upload_keystore.ps1",
                )
            }
            // Production ID yoksa veya Google test ID sızmışsa release FAIL.
            // Sahte/placeholder ID ve test App ID release'e KONMAZ.
            val missing = mutableListOf<String>()
            if (productionAdmobAppId.isBlank()) missing += "ADMOB_APP_ID / admobAppId"
            if (productionAdmobBannerId.isBlank()) missing += "ADMOB_BANNER_ID / admobBannerUnitId"
            if (productionAdmobInterstitialId.isBlank()) {
                missing += "ADMOB_INTERSTITIAL_ID / admobInterstitialUnitId"
            }
            if (missing.isNotEmpty()) {
                throw GradleException(
                    "Release AdMob production ID eksik: ${missing.joinToString(", ")}. " +
                        "android/admob.properties doldurun (şablon: admob.properties.example) " +
                        "veya env ayarlayın. Google test ID ile release üretilmez.",
                )
            }
            val allIds =
                listOf(
                    productionAdmobAppId,
                    productionAdmobBannerId,
                    productionAdmobInterstitialId,
                )
            if (allIds.any { it.contains(googleTestPublisherPrefix) }) {
                throw GradleException(
                    "Release AdMob config Google test publisher ID (3940256099942544) içeriyor. " +
                        "Production ID kullanın.",
                )
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            manifestPlaceholders["admobAppId"] = productionAdmobAppId
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-splashscreen:1.2.0")
}
