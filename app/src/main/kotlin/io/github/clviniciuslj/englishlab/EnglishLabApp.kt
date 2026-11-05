package io.github.clviniciuslj.englishlab

import android.app.Application

class EnglishLabApp : Application() {
    /** Criado sob demanda, na primeira vez em que a interface precisar. */
    val container: AppContainer by lazy { AppContainer(this) }
}
