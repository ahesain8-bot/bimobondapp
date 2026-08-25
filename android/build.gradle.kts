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
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            // External Native Build (CMake/ndk-build) defaults its .cxx
            // intermediate dir to <module-root>/.cxx/...  For Flutter plugins
            // that sit under Pub Cache (<LOCALAPPDATA>\Pub\Cache\hosted\...)
            // writes there are denied.  Redirect to the module's redirected
            // Gradle build dir (which is inside the project and writable).
            try {
                externalNativeBuild.cmake.buildStagingDirectory =
                    project.layout.buildDirectory.dir("cxx").get().asFile
            } catch (_: Throwable) {
                // Module has no cmake block configured; nothing to redirect.
            }
            try {
                externalNativeBuild.ndkBuild.buildStagingDirectory =
                    project.layout.buildDirectory.dir("cxx-ndkbuild").get().asFile
            } catch (_: Throwable) {
                // Module has no ndkBuild block configured; nothing to redirect.
            }
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
