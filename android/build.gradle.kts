// AGP and Kotlin versions are declared in settings.gradle.kts via the plugins block.
// The buildscript block is intentionally omitted — versions come from the pluginManagement.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}