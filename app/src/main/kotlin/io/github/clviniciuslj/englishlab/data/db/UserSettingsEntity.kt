package io.github.clviniciuslj.englishlab.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Linha única (id = 1) com as preferências do aluno e a data de criação dos dados locais.
 * Fica no Room, e não em outro armazenamento, para existir um único caminho de backup (ADR-9).
 */
@Entity(tableName = "user_settings")
data class UserSettingsEntity(
    @PrimaryKey val id: Int = SINGLETON_ID,
    val createdAtEpochMs: Long,
    val dailyMinutes: Int = DEFAULT_DAILY_MINUTES,
) {
    companion object {
        const val SINGLETON_ID = 1
        const val DEFAULT_DAILY_MINUTES = 45
    }
}
