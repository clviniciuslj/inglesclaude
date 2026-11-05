package io.github.clviniciuslj.englishlab.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.clviniciuslj.englishlab.data.db.AppDatabase
import io.github.clviniciuslj.englishlab.data.db.UserSettingsEntity
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Garante o que mais importa na entrega 1: o dado do aluno é criado uma única vez
 * e sobrevive a fechar e reabrir o banco.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [36])
class SettingsRepositoryTest {
    private lateinit var context: Context
    private val openDatabases = mutableListOf<AppDatabase>()
    private val fileDatabases = mutableListOf<String>()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @After
    fun tearDown() {
        openDatabases.forEach { if (it.isOpen) it.close() }
        fileDatabases.forEach { context.deleteDatabase(it) }
    }

    private fun inMemoryDatabase(): AppDatabase =
        Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
            .also { openDatabases += it }

    private fun fileDatabase(name: String): AppDatabase {
        if (name !in fileDatabases) fileDatabases += name
        return Room.databaseBuilder(context, AppDatabase::class.java, name)
            .allowMainThreadQueries()
            .build()
            .also { openDatabases += it }
    }

    private fun clockAt(epochMs: Long): Clock = Clock.fixed(Instant.ofEpochMilli(epochMs), ZoneOffset.UTC)

    @Test
    fun `inicializar duas vezes preserva a data de criacao original`() = runTest {
        val db = inMemoryDatabase()

        SettingsRepository(db.userSettingsDao(), clockAt(1_000)).ensureInitialized()
        SettingsRepository(db.userSettingsDao(), clockAt(9_999_999)).ensureInitialized()

        val row = db.userSettingsDao().get()
        assertNotNull(row)
        assertEquals(1_000L, row?.createdAtEpochMs)
        assertEquals(UserSettingsEntity.DEFAULT_DAILY_MINUTES, row?.dailyMinutes)
    }

    @Test
    fun `dados persistem ao fechar e reabrir o banco em arquivo`() = runTest {
        val name = "persist-test-${System.nanoTime()}.db"

        val first = fileDatabase(name)
        SettingsRepository(first.userSettingsDao(), clockAt(1_234)).ensureInitialized()
        first.close()

        val reopened = fileDatabase(name)
        SettingsRepository(reopened.userSettingsDao(), clockAt(8_888_888)).ensureInitialized()

        assertEquals(1_234L, reopened.userSettingsDao().get()?.createdAtEpochMs)
    }

    @Test
    fun `observe emite a configuracao depois da inicializacao`() = runTest {
        val db = inMemoryDatabase()
        val repository = SettingsRepository(db.userSettingsDao(), clockAt(5_000))

        repository.ensureInitialized()

        val row = repository.observe().first()
        assertNotNull(row)
        assertEquals(5_000L, row?.createdAtEpochMs)
    }

    @Test
    fun `a versao do esquema reportada no aparelho e 1`() = runTest {
        val db = inMemoryDatabase()
        assertEquals(1, StorageDiagnostics(db).schemaVersion())
    }
}
