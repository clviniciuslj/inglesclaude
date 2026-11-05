package io.github.clviniciuslj.englishlab.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.unit.sp

private val Base = Typography()

/** Tipografia um pouco maior que o padrão, para leitura confortável (em sp: respeita a escala do sistema). */
val AppTypography = Typography(
    bodyLarge = Base.bodyLarge.copy(fontSize = 17.sp, lineHeight = 26.sp),
    bodyMedium = Base.bodyMedium.copy(fontSize = 15.sp, lineHeight = 22.sp),
)
