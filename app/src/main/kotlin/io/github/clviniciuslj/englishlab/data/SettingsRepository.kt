package io.github.clviniciuslj.englishlab.data

import io.github.clviniciuslj.englishlab.data.db.UserSettingsDao
import io.github.clviniciuslj.englishlab.data.db.UserSettingsEntity
import java.time.Clock
import kotlinx.coroutines.flow.Flow

class SettingsRepository(
    private val dao: UserSettingsDao,
    private val clock: Clock,
) {
    fun observe(): Flow<UserSettingsEntity?> = dao.observe()

    /** Cria a linha de configurações no primeiro uso. Chamadas seguintes não alteram nada. */
    suspend fun ensureInitialized() {
        dao.insertIfAbsent(UserSettingsEntity(createdAtEpochMs = clock.millis()))
    }
}
