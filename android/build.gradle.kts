allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Override Kotlin language version for all sub-projects to avoid "version 1.6 unsupported" errors
allprojects {
    // Sauf mobile_scanner : depuis la 7.4, son code compte sur les smart casts
    // du compilateur K2 (variable affectée dans un try, puis lue). Rabattu en
    // 1.9, il ne compile plus (« Type mismatch: inferred type is Bitmap? but
    // Bitmap was expected », MobileScanner.kt). Il ne fixe lui-même aucune
    // version de langage : il prend donc celle du compilateur (2.2).
    // Même cas pour stream_video_push_notification (appels audio Stream Video) :
    // StreamTelecomManager.kt utilise un `if` en expression sans `else`, accepté
    // par K2 seulement (« 'if' must have both main and 'else' branches »).
    if (project.name in setOf("mobile_scanner", "stream_video_push_notification")) return@allprojects
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
            apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
