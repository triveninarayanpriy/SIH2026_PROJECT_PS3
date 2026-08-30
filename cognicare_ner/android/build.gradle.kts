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
    
    afterEvaluate {
        val androidPlugin = project.extensions.findByName("android")
        if (androidPlugin != null) {
            try {
                androidPlugin.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(androidPlugin, 36)
            } catch (e: Exception) {
                try {
                    androidPlugin.javaClass.getMethod("setCompileSdk", Int::class.java).invoke(androidPlugin, 36)
                } catch (e2: Exception) {}
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
