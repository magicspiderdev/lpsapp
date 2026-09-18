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

        // Android 7.0. Fixo de propósito, e não `flutter.minSdkVersion`: este
        // número é o único que deixa telemóveis de fora, e uma actualização do
        // Flutter podia subi-lo sem ninguém dar por isso — quem ficasse abaixo
        // deixava de receber actualizações, em silêncio. Subir daqui é uma
        // decisão a tomar com os números da Play Console à frente, não um efeito
        // secundário de `flutter upgrade`.
        //
        // 24 é hoje o chão do próprio Flutter, por isso não dá para descer: a
        // app antiga chegava ao 21 por ter sido feita com um Flutter mais velho.
        minSdk = 24

        // Estes seguem o Flutter de propósito: é o que mantém a app a par das
        // regras novas do Android. Nenhum deles exclui aparelhos.
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

            // Um release de ensaio não se instala por cima da app publicada: o
            // Android recusa (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) quando a
            // assinatura não é a mesma. Com `LPS_SUFIXO_ENSAIO=.ensaio` o APK
            // leva outro identificador e convive com ela no mesmo telemóvel.
            System.getenv("LPS_SUFIXO_ENSAIO")?.let {
                applicationIdSuffix = it
                manifestPlaceholders["appName"] = "LPS Neo ensaio"
            }
        }
    }
}

flutter {
    source = "../.."
}
