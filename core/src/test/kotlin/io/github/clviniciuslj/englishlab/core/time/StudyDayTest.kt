package io.github.clviniciuslj.englishlab.core.time

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class StudyDayTest {
    private val saoPaulo = ZoneId.of("America/Sao_Paulo")
    private val newYork = ZoneId.of("America/New_York")

    private fun at(zone: ZoneId, year: Int, month: Int, day: Int, hour: Int, minute: Int): Instant =
        LocalDateTime.of(year, month, day, hour, minute).atZone(zone).toInstant()

    @Test
    fun `antes das 04h ainda e o dia de estudo anterior`() {
        val instant = at(saoPaulo, 2026, 11, 5, 3, 59)
        assertEquals(LocalDate.of(2026, 11, 4), StudyDay.of(instant, saoPaulo))
    }

    @Test
    fun `as 04h comeca o novo dia de estudo`() {
        val instant = at(saoPaulo, 2026, 11, 5, 4, 0)
        assertEquals(LocalDate.of(2026, 11, 5), StudyDay.of(instant, saoPaulo))
    }

    @Test
    fun `meia-noite pertence ao dia de estudo anterior`() {
        val instant = at(saoPaulo, 2026, 11, 5, 0, 0)
        assertEquals(LocalDate.of(2026, 11, 4), StudyDay.of(instant, saoPaulo))
    }

    @Test
    fun `fim do dia pertence ao proprio dia`() {
        val instant = at(saoPaulo, 2026, 11, 5, 23, 59)
        assertEquals(LocalDate.of(2026, 11, 5), StudyDay.of(instant, saoPaulo))
    }

    @Test
    fun `virada de ano respeita o dia de estudo`() {
        val instant = at(saoPaulo, 2027, 1, 1, 2, 0)
        assertEquals(LocalDate.of(2026, 12, 31), StudyDay.of(instant, saoPaulo))
    }

    @Test
    fun `o mesmo instante cai em dias diferentes conforme o fuso`() {
        // 2026-11-05T06:00Z = 03:00 em São Paulo (UTC-3, dia anterior) e 01:00 em Nova York (UTC-5, dia anterior).
        val instant = Instant.parse("2026-11-05T06:00:00Z")
        assertEquals(LocalDate.of(2026, 11, 4), StudyDay.of(instant, saoPaulo))
        // 2026-11-05T09:00Z = 06:00 em São Paulo (mesmo dia) e 04:00 em Nova York (mesmo dia).
        val later = Instant.parse("2026-11-05T09:00:00Z")
        assertEquals(LocalDate.of(2026, 11, 5), StudyDay.of(later, saoPaulo))
        assertEquals(LocalDate.of(2026, 11, 5), StudyDay.of(later, newYork))
    }

    @Test
    fun `horario de verao nao desloca a virada das 04h`() {
        // Em 2026-03-08 os relógios de Nova York saltam de 02:00 para 03:00.
        assertEquals(
            LocalDate.of(2026, 3, 7),
            StudyDay.of(at(newYork, 2026, 3, 8, 3, 30), newYork),
        )
        assertEquals(
            LocalDate.of(2026, 3, 8),
            StudyDay.of(at(newYork, 2026, 3, 8, 4, 0), newYork),
        )
    }

    @Test
    fun `fim do horario de verao com hora repetida continua no dia anterior`() {
        // Em 2026-11-01 a hora 01:00 se repete em Nova York; as duas ocorrências são antes das 04h.
        val firstOccurrence = LocalDateTime.of(2026, 11, 1, 1, 30).atZone(newYork).withEarlierOffsetAtOverlap().toInstant()
        val secondOccurrence = LocalDateTime.of(2026, 11, 1, 1, 30).atZone(newYork).withLaterOffsetAtOverlap().toInstant()
        assertEquals(LocalDate.of(2026, 10, 31), StudyDay.of(firstOccurrence, newYork))
        assertEquals(LocalDate.of(2026, 10, 31), StudyDay.of(secondOccurrence, newYork))
        assertEquals(LocalDate.of(2026, 11, 1), StudyDay.of(at(newYork, 2026, 11, 1, 4, 0), newYork))
    }

    @Test
    fun `hora de virada personalizada`() {
        val instant = at(saoPaulo, 2026, 11, 5, 5, 59)
        assertEquals(LocalDate.of(2026, 11, 5), StudyDay.of(instant, saoPaulo, rolloverHour = 0))
        assertEquals(LocalDate.of(2026, 11, 4), StudyDay.of(instant, saoPaulo, rolloverHour = 6))
    }

    @Test
    fun `hora de virada invalida e rejeitada`() {
        assertFailsWith<IllegalArgumentException> { StudyDay.of(Instant.EPOCH, saoPaulo, rolloverHour = 24) }
        assertFailsWith<IllegalArgumentException> { StudyDay.of(Instant.EPOCH, saoPaulo, rolloverHour = -1) }
    }
}
