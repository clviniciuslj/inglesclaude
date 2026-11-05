package io.github.clviniciuslj.englishlab

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import io.github.clviniciuslj.englishlab.ui.home.HomeScreen
import io.github.clviniciuslj.englishlab.ui.home.HomeViewModel
import io.github.clviniciuslj.englishlab.ui.theme.EnglishLabTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val container = (application as EnglishLabApp).container
        setContent {
            EnglishLabTheme {
                val viewModel: HomeViewModel = viewModel(factory = HomeViewModel.factory(container))
                HomeScreen(viewModel)
            }
        }
    }
}
