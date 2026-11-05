package io.github.clviniciuslj.englishlab.core.time

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * "Dia de estudo": o dia civil local, mas que só "vira" às [rolloverHour] (padrão 04:00).
 *
 * Quem estuda à 01:30 ainda pertence ao dia de estudo anterior, o que evita quebrar a
 * sequência de dias por causa de sessões na madrugada.
 *
 * A regra usa o relógio de parede local (hora marcada no relógio), e não subtrai horas
 * corridas. Assim, a virada continua às 04:00 mesmo em dias de mudança de horário de verão.
 */
object StudyDay {
    const val DEFAULT_ROLLOVER_HOUR: Int = 4

    fun of(
        instant: Instant,
        zone: ZoneId,
        rolloverHour: Int = DEFAULT_ROLLOVER_HOUR,
    ): LocalDate {
        require(rolloverHour in 0..23) { "rolloverHour deve estar entre 0 e 23, mas foi $rolloverHour" }
        val local = instant.atZone(zone).toLocalDateTime()
        val date = local.toLocalDate()
        return if (local.hour < rolloverHour) date.minusDays(1) else date
    }
}
