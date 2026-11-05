// Todos os plugins são declarados aqui (apply false) para compartilharem o mesmo classloader
// (o KSP precisa enxergar as classes do Android Gradle Plugin).
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.ksp) apply false
}
