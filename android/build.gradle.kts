// Top-level build file where you can add configuration options common to all sub-projects/modules.

plugins {
    // Firebase requires this for Google Services
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- Redirect the build directory to the root-level build folder (for Flutter conventions) ---
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// --- Add clean task ---
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
