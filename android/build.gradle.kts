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
subprojects {
    if (project.name != "app") {
        plugins.withType<org.jetbrains.kotlin.gradle.plugin.KotlinBasePlugin>().configureEach {
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinTopLevelExtension> {
                jvmToolchain(17)
            }
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}