package io.github.clviniciuslj.englishlab.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.clviniciuslj.englishlab.R
import java.time.format.DateTimeFormatter
import java.util.Locale

private val ptBr: Locale = Locale.forLanguageTag("pt-BR")
private val dateTimeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm", ptBr)
private val dateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy", ptBr)

@Composable
fun HomeScreen(viewModel: HomeViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HomeContent(state)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeContent(state: HomeUiState) {
    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.home_title)) }) },
    ) { innerPadding ->
        when (state) {
            HomeUiState.Loading -> LoadingBody(Modifier.padding(innerPadding))
            is HomeUiState.Ready -> ReadyBody(state, Modifier.padding(innerPadding))
        }
    }
}

@Composable
private fun LoadingBody(modifier: Modifier = Modifier) {
    val description = stringResource(R.string.home_loading)
    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(modifier = Modifier.semantics { contentDescription = description })
    }
}

@Composable
private fun ReadyBody(state: HomeUiState.Ready, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        InfoCard(title = stringResource(R.string.home_test_version_title)) {
            Text(
                text = stringResource(R.string.home_test_version_body),
                style = MaterialTheme.typography.bodyLarge,
            )
        }

        InfoCard(title = stringResource(R.string.home_state_title)) {
            InfoRow(
                label = stringResource(R.string.home_label_version),
                value = stringResource(
                    R.string.home_value_version,
                    state.appInfo.versionName,
                    state.appInfo.buildNumber,
                    state.appInfo.commit,
                ),
            )
            InfoRow(
                label = stringResource(R.string.home_label_data_created),
                value = dateTimeFormatter.format(state.dataCreatedAt.atZone(state.zone)),
            )
            InfoRow(
                label = stringResource(R.string.home_label_study_day),
                value = stringResource(
                    R.string.home_value_study_day,
                    dateFormatter.format(state.studyDayToday),
                    state.studyDayNumber,
                ),
            )
            InfoRow(
                label = stringResource(R.string.home_label_daily_goal),
                value = stringResource(R.string.home_value_daily_goal, state.dailyMinutes),
            )
            InfoRow(
                label = stringResource(R.string.home_label_database),
                value = stringResource(R.string.home_value_database, state.databaseSchemaVersion),
            )
            InfoRow(
                label = stringResource(R.string.home_label_internet),
                value = stringResource(
                    if (state.appInfo.declaresInternetPermission) {
                        R.string.home_value_internet_present
                    } else {
                        R.string.home_value_internet_absent
                    },
                ),
            )
        }
    }
}

@Composable
private fun InfoCard(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(text = title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(text = value, style = MaterialTheme.typography.bodyLarge)
    }
}
