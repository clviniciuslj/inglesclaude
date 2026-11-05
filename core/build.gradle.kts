import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
}

// Bytecode Java 17: compatível com o :app (Android/D8). Este módulo não depende de Android.
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    testImplementation(libs.kotlin.test)
    testImplementation(libs.junit4)
}

tasks.test {
    // JUnit 4 em todo o projeto (Robolectric e AndroidX Test exigem JUnit 4).
    useJUnit()
    testLogging {
        events("passed", "failed", "skipped")
    }
}
