import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Base64
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

// Clé Google Maps du manifest natif. Elle ne passe pas par le code Dart : Gradle
// la lit, dans cet ordre, pour chaque nom de variable :
//   1. la variable d'environnement (CI, build-release.yml) ;
//   2. le fichier passé à --dart-define-from-file (env.staging.json,
//      env.prod.json…), que Flutter transmet à Gradle dans la propriété
//      `dart-defines` (entrées KEY=VALUE encodées en base64) ;
//   3. env.dev.json, repli historique du développement local.
// Sans l'étape 2, un build lancé à la main avec env.staging.json prenait la
// clé de env.dev.json, ou rien : l'app se lançait et la carte restait vide
// (builds 1.0.0+78 à +83, puis Sentry FLUTTER-A7 sur le build 100).
//
// Deux noms, parce que deux clés. GOOGLE_MAPS_ANDROID_API_KEY est la clé
// restreinte Android (yadony-prod-android : package com.yadony.yadony + SHA-1,
// API maps-android-backend). GOOGLE_MAPS_API_KEY est celle qu'iOS lit
// (Info.plist, xcconfig) : en production c'est yadony-prod-ios, restreinte au
// bundle iOS, que le SDK Maps Android refuse. Une seule variable servait les
// deux plateformes : le build 143 publié sur Play affichait une carte vide
// (Sentry YADONY-FLUTTER-PROD-1T). Le repli sur GOOGLE_MAPS_API_KEY ne reste
// permis qu'en dev/staging, où la même clé non restreinte à une plateforme sert
// encore les deux ; en production, l'absence de la clé Android est une erreur.
val dartDefines: Map<String, String> =
    (findProperty("dart-defines") as? String).orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
        }
        .filter { it.contains("=") }
        .associate { it.substringBefore("=") to it.substringAfter("=") }

val devEnvJson: Map<String, Any?> = run {
    val envFile = rootProject.file("../env.dev.json")
    if (envFile.exists()) {
        @Suppress("UNCHECKED_CAST")
        JsonSlurper().parse(envFile) as Map<String, Any?>
    } else emptyMap()
}

// ENVIRONMENT vient du même fichier d'environnement que la clé (env.prod.json
// porte "production"), ou de la variable du même nom.
val isProductionEnvironment: Boolean =
    (System.getenv("ENVIRONMENT")?.takeIf { it.isNotBlank() } ?: dartDefines["ENVIRONMENT"])
        ?.trim() == "production"

// env.dev.json n'est jamais une source en production : une clé de dev dans un
// binaire publié serait la même panne silencieuse sous un autre nom.
fun resolveBuildValue(name: String): String =
    System.getenv(name)?.takeIf { it.isNotBlank() }
        ?: dartDefines[name]?.takeIf { it.isNotBlank() }
        ?: if (isProductionEnvironment) "" else (devEnvJson[name] as? String).orEmpty()

val googleMapsAndroidApiKey: String = resolveBuildValue("GOOGLE_MAPS_ANDROID_API_KEY")

val googleMapsApiKey: String = when {
    googleMapsAndroidApiKey.isNotBlank() -> googleMapsAndroidApiKey
    // Jamais de repli silencieux sur la clé iOS en production : manifest vide,
    // et la tâche requireAndroidMapsKeyForProduction plus bas fait échouer
    // tout build release.
    isProductionEnvironment -> ""
    else -> resolveBuildValue("GOOGLE_MAPS_API_KEY")
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
    // La clé réellement injectée dans le manifest, pas une relecture des
    // fichiers par le script : c'est elle qui décide si la carte s'affiche.
    environment("GOOGLE_MAPS_ANDROID_API_KEY", googleMapsApiKey)
}

// Un build release de production sans clé Android dédiée échoue ici, AAB comme
// APK : mieux vaut aucun binaire qu'une carte vide publiée (build 143). Les
// builds debug et ceux de dev/staging ne sont pas concernés.
val requireAndroidMapsKeyForProduction = tasks.register("requireAndroidMapsKeyForProduction") {
    val production = isProductionEnvironment
    val androidKey = googleMapsAndroidApiKey
    doLast {
        if (production && androidKey.isBlank()) {
            throw GradleException(
                "GOOGLE_MAPS_ANDROID_API_KEY absente pour un build release de production. " +
                    "La renseigner dans env.prod.json (clé yadony-prod-android) ou l'exporter. " +
                    "GOOGLE_MAPS_API_KEY est la clé iOS : le SDK Maps Android la refuse."
            )
        }
    }
}

tasks.matching { it.name.startsWith("bundle") && it.name.endsWith("Release") }
    .configureEach { dependsOn(verifyAndroidReleaseConfig) }

tasks.matching {
    (it.name.startsWith("bundle") || it.name.startsWith("assemble")) && it.name.endsWith("Release")
}.configureEach { dependsOn(requireAndroidMapsKeyForProduction) }

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
