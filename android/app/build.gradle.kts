import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Keystore de signature release. Chargé depuis android/key.properties
// (gitignoré, jamais commité). Absent → on retombe sur la clé debug pour que
// `flutter run --release` fonctionne en local sans keystore. Voir
// android/key.properties.example pour le format.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Read GOOGLE_MAPS_API_KEY: env var first (CI/release), then env.dev.json (local dev fallback)
val googleMapsApiKey: String = run {
    System.getenv("GOOGLE_MAPS_API_KEY")?.takeIf { it.isNotBlank() }?.let { return@run it }
    val envFile = rootProject.file("../env.dev.json")
    if (envFile.exists()) {
        @Suppress("UNCHECKED_CAST")
        val json = JsonSlurper().parse(envFile) as Map<String, Any?>
        (json["GOOGLE_MAPS_API_KEY"] as? String).orEmpty()
    } else ""
}

android {
    namespace = "com.yadony.yadony"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yadony.yadony"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Vrai keystore release si key.properties présent, sinon debug
            // (permet `flutter run --release` local sans keystore de prod).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 : minification + suppression du code/ressources morts +
            // obfuscation Kotlin/Java. Règles de préservation dans
            // proguard-rules.pro (Stripe, Play Core, plugins réflexifs).
            // NB : l'obfuscation du code DART se fait séparément au build
            // Flutter : `flutter build appbundle --obfuscate
            //   --split-debug-info=build/debug-info
            //   --dart-define-from-file=env.prod.json`.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Garde-fou de configuration native — pendant Android de la phase Xcode
// « Verify iOS Release Config ».
//
// google-services.json est gitignoré et s'échange à la main : rien n'empêchait
// jusqu'ici un AAB de production de partir avec la configuration Google de
// staging. L'application se compile, s'installe et se lance ; ce sont la
// connexion Google et la vérification par SMS qui échouent une fois publiée.
// C'est exactement ce qui est arrivé à l'IPA 1.0.0+40.
//
// Accroché aux seules tâches `bundle*Release`, celles qui produisent l'AAB
// déposé sur Play. Un `flutter run --release` local passe par `assembleRelease`
// et reste donc libre : travailler en release contre staging est légitime, et
// aucun binaire n'en sort. La phase iOS, elle, bloque tout build Release —
// divergence assumée, c'est le côté Android qui vise juste.
val verifyAndroidReleaseConfig = tasks.register<Exec>("verifyAndroidReleaseConfig") {
    val repoRoot = rootProject.projectDir.parentFile
    workingDir = repoRoot
    commandLine("$repoRoot/tool/verify_android_release_config.sh")
}

tasks.matching { it.name.startsWith("bundle") && it.name.endsWith("Release") }
    .configureEach { dependsOn(verifyAndroidReleaseConfig) }

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.material:material:1.12.0")
}
