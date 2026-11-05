package io.github.clviniciuslj.englishlab.info

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.github.clviniciuslj.englishlab.BuildConfig

data class AppInfo(
    val versionName: String,
    val versionCode: Int,
    /** Número da execução do CI que gerou o APK ("local" em builds feitos fora do CI). */
    val buildNumber: String,
    val commit: String,
    /** Verificação em tempo de execução: o app não deve declarar a permissão de internet. */
    val declaresInternetPermission: Boolean,
)

fun readAppInfo(context: Context): AppInfo {
    val packageManager = context.packageManager
    val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getPackageInfo(
            context.packageName,
            PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
        )
    } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
    }
    val requestedPermissions = packageInfo.requestedPermissions?.toList().orEmpty()

    return AppInfo(
        versionName = BuildConfig.VERSION_NAME,
        versionCode = BuildConfig.VERSION_CODE,
        buildNumber = BuildConfig.BUILD_NUMBER,
        commit = BuildConfig.GIT_SHA,
        declaresInternetPermission = Manifest.permission.INTERNET in requestedPermissions,
    )
}
