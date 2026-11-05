package io.github.clviniciuslj.englishlab.data

import io.github.clviniciuslj.englishlab.data.db.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class StorageDiagnostics(private val database: AppDatabase) {
    /** Versão do esquema do banco realmente aberto no aparelho (PRAGMA user_version). */
    suspend fun schemaVersion(): Int = withContext(Dispatchers.IO) {
        database.openHelper.readableDatabase.version
    }
}
