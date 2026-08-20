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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
}

// FORCE ALL SUBPROJECTS/PLUGINS TO SDK 36 & STRIP LEGACY MANIFEST PACKAGES
subprojects {
    val configureProject = Action<Project> {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")

            // 1. Force SDK 36 compilation targets
            try {
                androidExt?.javaClass?.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)?.invoke(androidExt, 36)
            } catch (e: Exception) {
                // Ignore if method not found
            }

            // 2. 🛡️ MODERN GRADLE FIX: Intercept and clean legacy manifests in third-party plugins
            project.tasks.configureEach {
                if (name.contains("process") && name.contains("Manifest")) {
                    doFirst {
                        val manifestFiles = project.fileTree(mapOf("dir" to "src/main", "include" to "AndroidManifest.xml"))
                        manifestFiles.forEach { file ->
                            if (file.exists()) {
                                var contents = file.readText()
                                // Regex strips out the illegal package="xxx" attribute from the manifest tag
                                if (contents.contains("package=")) {
                                    contents = contents.replace(Regex("""package="[^"]*""""), "")
                                    file.writeText(contents)
                                    logger.lifecycle("🛡️ Successfully stripped legacy package attribute from: ${file.absolutePath}")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject.execute(project)
    } else {
        project.afterEvaluate(configureProject)
    }
}