plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

// ---- Versão ------------------------------------------------------------------------------
val appVersionName = "0.1.0"

// versionCode sempre crescente: minutos desde 2026-01-01 UTC. Uma atualização por cima exige
// versionCode maior que o instalado; usar o relógio evita depender do contador de execuções do CI.
val versionCodeEpochSeconds = 1_767_225_600L
val computedVersionCode =
    ((System.currentTimeMillis() / 1000L - versionCodeEpochSeconds) / 60L).toInt().coerceAtLeast(1)

val ciBuildNumber = providers.environmentVariable("GITHUB_RUN_NUMBER").orElse("local")
val ciCommit = providers.environmentVariable("GITHUB_SHA").map { it.take(7) }.orElse("local")

// ---- Assinatura estável (somente quando as variáveis de ambiente existem) -----------------
// O CI injeta estas variáveis apenas nos eventos autorizados (branch main ou execução manual).
// Em pull requests elas não existem: o build usa a chave de debug efêmera e o APK não é publicado.
val stableKeystorePath = providers.environmentVariable("ENGLISHLAB_KEYSTORE_PATH")
val requireStableSigning = providers.gradleProperty("requireStableSigning").isPresent

if (requireStableSigning && !stableKeystorePath.isPresent) {
    throw GradleException(
        "-PrequireStableSigning exige ENGLISHLAB_KEYSTORE_PATH, ENGLISHLAB_KEYSTORE_PASSWORD, " +
            "ENGLISHLAB_KEY_ALIAS e ENGLISHLAB_KEY_PASSWORD. Veja docs/ASSINATURA.md.",
    )
}

android {
    namespace = "io.github.clviniciuslj.englishlab"
    compileSdk = 37

    defaultConfig {
        applicationId = "io.github.clviniciuslj.englishlab"
        minSdk = 26
        targetSdk = 36
        versionCode = computedVersionCode
        versionName = appVersionName

        buildConfigField("String", "BUILD_NUMBER", "\"${ciBuildNumber.get()}\"")
        buildConfigField("String", "GIT_SHA", "\"${ciCommit.get()}\"")
    }

    signingConfigs {
        if (stableKeystorePath.isPresent) {
            create("stable") {
                storeFile = file(stableKeystorePath.get())
                storePassword = providers.environmentVariable("ENGLISHLAB_KEYSTORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("ENGLISHLAB_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("ENGLISHLAB_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.findByName("stable") ?: signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }

    lint {
        abortOnError = true
        warningsAsErrors = false
    }
}

// Esquemas do Room exportados e versionados em app/schemas (base dos testes de migração).
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

// Falhas de teste aparecem completas (com causa e pilha) no log do CI.
tasks.withType<Test>().configureEach {
    testLogging {
        events("passed", "failed", "skipped")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
        showCauses = true
        showStackTraces = true
    }
}

dependencies {
    implementation(project(":core"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.ext.junit)
    testImplementation(libs.kotlinx.coroutines.test)
}
