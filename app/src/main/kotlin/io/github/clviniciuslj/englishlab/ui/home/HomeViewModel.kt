package io.github.clviniciuslj.englishlab.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.github.clviniciuslj.englishlab.AppContainer
import io.github.clviniciuslj.englishlab.core.time.StudyDay
import io.github.clviniciuslj.englishlab.data.SettingsRepository
import io.github.clviniciuslj.englishlab.data.StorageDiagnostics
import io.github.clviniciuslj.englishlab.data.db.UserSettingsEntity
import io.github.clviniciuslj.englishlab.info.AppInfo
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface HomeUiState {
    data object Loading : HomeUiState

    data class Ready(
        val appInfo: AppInfo,
        val dataCreatedAt: Instant,
        val zone: ZoneId,
        val studyDayToday: LocalDate,
        val studyDayNumber: Int,
        val dailyMinutes: Int,
        val databaseSchemaVersion: Int,
    ) : HomeUiState
}

class HomeViewModel(
    private val settings: SettingsRepository,
    private val storage: StorageDiagnostics,
    private val appInfo: AppInfo,
    private val clock: Clock,
) : ViewModel() {

    val uiState: StateFlow<HomeUiState> = settings.observe()
        .filterNotNull()
        .map { entity -> buildReadyState(entity) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), HomeUiState.Loading)

    init {
        viewModelScope.launch { settings.ensureInitialized() }
    }

    private suspend fun buildReadyState(entity: UserSettingsEntity): HomeUiState {
        val zone = clock.zone
        val createdAt = Instant.ofEpochMilli(entity.createdAtEpochMs)
        val firstStudyDay = StudyDay.of(createdAt, zone)
        val today = StudyDay.of(clock.instant(), zone)
        val dayNumber = (ChronoUnit.DAYS.between(firstStudyDay, today) + 1).toInt().coerceAtLeast(1)

        return HomeUiState.Ready(
            appInfo = appInfo,
            dataCreatedAt = createdAt,
            zone = zone,
            studyDayToday = today,
            studyDayNumber = dayNumber,
            dailyMinutes = entity.dailyMinutes,
            databaseSchemaVersion = storage.schemaVersion(),
        )
    }

    companion object {
        private const val STOP_TIMEOUT_MS = 5_000L

        fun factory(container: AppContainer): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                HomeViewModel(
                    settings = container.settingsRepository,
                    storage = container.storageDiagnostics,
                    appInfo = container.appInfo,
                    clock = container.clock,
                )
            }
        }
    }
}
