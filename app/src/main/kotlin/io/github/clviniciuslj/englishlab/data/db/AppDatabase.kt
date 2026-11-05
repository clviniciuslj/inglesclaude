package io.github.clviniciuslj.englishlab.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Banco local do English Lab (Room). Esquema exportado em app/schemas (ADR-8).
 *
 * Regra de ouro: NUNCA usar fallbackToDestructiveMigration. Toda mudança de esquema exige
 * uma migração testada, porque o progresso do aluno mora aqui.
 */
@Database(
    entities = [UserSettingsEntity::class],
    version = 1,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userSettingsDao(): UserSettingsDao

    companion object {
        const val FILE_NAME = "englishlab.db"

        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, FILE_NAME).build()
    }
}
