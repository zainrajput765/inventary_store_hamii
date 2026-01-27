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

// --- FINAL FIX FOR ISAR & SDK ERRORS ---
subprojects {
    // Check ensuring we don't crash the main 'app' which is already evaluated
    if (project.name != "app") {
        project.afterEvaluate {
            val android = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            if (android != null) {
                // 1. Force Compile SDK to 36 (Fixes 'lStar' error)
                android.compileSdkVersion(36)

                // 2. Force Target SDK to 36 (Fixes 'path_provider' error)
                android.defaultConfig {
                    targetSdkVersion(36)
                }

                // 3. Fix 'Namespace not specified' error
                if (android.namespace == null) {
                    android.namespace = project.group.toString()
                }
            }
        }
    }
}