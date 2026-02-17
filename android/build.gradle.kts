allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (project.hasProperty("android")) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    val packageMatch = Regex("package=\"([^\"]+)\"").find(content)
                    if (packageMatch != null) {
                        val packageName = packageMatch.groups[1]?.value
                        if (packageName != null && namespace == null) {
                            namespace = packageName
                        }
                        
                        // Add a task to strip the package attribute from the manifest
                        val stripManifestPackage = tasks.register("stripManifestPackage") {
                            doLast {
                                if (manifestFile.exists()) {
                                    val newContent = manifestFile.readText().replace(Regex("""\s*package="[^"]*""""), "")
                                    manifestFile.writeText(newContent)
                                }
                            }
                        }
                        
                        // Make sure this runs before manifest processing
                        tasks.matching { it.name.startsWith("process") && it.name.endsWith("Manifest") }.configureEach {
                            dependsOn(stripManifestPackage)
                        }
                    }
                }

                if (namespace == null) {
                    namespace = "com.example.${project.name.replace("-", "_")}"
                }
                
                compileSdkVersion(36)

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}