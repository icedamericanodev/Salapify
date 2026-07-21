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
    // Some plugins (file_picker pulls flutter_plugin_android_lifecycle) require a
    // newer compileSdk than the Flutter default, and they compile their OWN
    // module against that default, so setting it only on :app is not enough.
    // Force every Android subproject to compile against 36. Reflection keeps this
    // working across AGP majors: the compileSdk property setter on AGP 8/9, or
    // the older compileSdkVersion(int) method as a fallback.
    //
    // Registered BEFORE evaluationDependsOn below so the callback is added while
    // the subproject is still being configured, and guarded on state.executed so
    // it never throws "afterEvaluate when already evaluated" if a project (e.g.
    // :app) was pulled in and fully evaluated early.
    val forceCompileSdk = {
        val android = extensions.findByName("android")
        if (android != null) {
            val methods = android.javaClass.methods
            val setter = methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterCount == 1
            }
            if (setter != null) {
                runCatching { setter.invoke(android, 36) }
            } else {
                methods.firstOrNull {
                    it.name == "compileSdkVersion" && it.parameterCount == 1 &&
                        it.parameterTypes[0] == Integer.TYPE
                }?.let { runCatching { it.invoke(android, 36) } }
            }
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
