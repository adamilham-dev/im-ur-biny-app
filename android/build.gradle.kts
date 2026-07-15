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

// Force consistent JVM 17 target across all subprojects (fixes tflite_flutter mismatch)
subprojects {
    afterEvaluate {
        // Override Java compileOptions in android extension
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                // Use reflection-style configuration via Groovy/MutableProperty
                try {
                    val compileOptions = androidExt.javaClass
                        .getMethod("getCompileOptions")
                        .invoke(androidExt)
                    compileOptions.javaClass
                        .getMethod("setSourceCompatibility", JavaVersion::class.java)
                        .invoke(compileOptions, JavaVersion.VERSION_17)
                    compileOptions.javaClass
                        .getMethod("setTargetCompatibility", JavaVersion::class.java)
                        .invoke(compileOptions, JavaVersion.VERSION_17)
                } catch (_: Exception) { }
                // Force compileSdk for outdated plugins (tflite_flutter uses 31)
                try {
                    androidExt.javaClass
                        .getMethod("setCompileSdkVersion", Int::class.java)
                        .invoke(androidExt, 35)
                } catch (_: Exception) { }
            }
        }
        // Override Kotlin JVM target
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
