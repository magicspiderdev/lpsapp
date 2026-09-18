import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// A app substitui a antiga na Play Store: o release tem de ser assinado com a
// chave dela. O `key.properties` e o `.jks` ficam fora do repositório (ver
// `android/.gitignore`); sem eles, só se constrói debug.
val chaves = Properties().apply {
    val ficheiro = rootProject.file("key.properties")
    if (ficheiro.exists()) ficheiro.inputStream().use { load(it) }
}

android {
    namespace = "pt.magicspider.mslps"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "pt.magicspider.mslps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "LPS Neo"
    }

    signingConfigs {
        if (chaves.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(chaves.getProperty("storeFile"))
                storePassword = chaves.getProperty("storePassword")
                keyAlias = chaves.getProperty("keyAlias")
                keyPassword = chaves.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Em debug convive com a app antiga (mesmo applicationId, outra assinatura)
        // no telemóvel de quem testa.
        debug {
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "LPS Neo dev"
        }
        release {
            // Sem `key.properties` fica com a chave de debug, para `flutter run
            // --release` funcionar — mas um APK desses não entra na Play Store.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
