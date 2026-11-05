package io.github.clviniciuslj.englishlab

import android.content.Context
import io.github.clviniciuslj.englishlab.data.SettingsRepository
import io.github.clviniciuslj.englishlab.data.StorageDiagnostics
import io.github.clviniciuslj.englishlab.data.db.AppDatabase
import io.github.clviniciuslj.englishlab.info.AppInfo
import io.github.clviniciuslj.englishlab.info.readAppInfo
import java.time.Clock

/** Injeção de dependências manual (ADR-2): cria e guarda as dependências do aplicativo. */
class AppContainer(context: Context) {
    private val appContext = context.applicationContext

    val clock: Clock = Clock.systemDefaultZone()

    val database: AppDatabase by lazy { AppDatabase.create(appContext) }

    val settingsRepository: SettingsRepository by lazy {
        SettingsRepository(database.userSettingsDao(), clock)
    }

    val storageDiagnostics: StorageDiagnostics by lazy { StorageDiagnostics(database) }

    val appInfo: AppInfo by lazy { readAppInfo(appContext) }
}
