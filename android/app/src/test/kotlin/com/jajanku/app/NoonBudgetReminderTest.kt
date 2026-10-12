package com.jajanku.app

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class NoonBudgetReminderTest {
    private fun at(day: Int, hour: Int, minute: Int = 0): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone("Asia/Jakarta")).apply {
            clear()
            set(2026, Calendar.OCTOBER, day, hour, minute)
        }

    @Test fun schedulesAtOnePmTodayOrTomorrow() {
        assertEquals(at(6, 13).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 12)))
        assertEquals(at(6, 13).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 12, 59)))
        assertEquals(at(7, 13).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 13)))
        assertEquals(at(7, 13).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 23)))
        assertEquals(at(7, 13).timeInMillis, NoonBudgetReminder.nextNoon(at(7, 0)))
        val endOfMonth = at(31, 14)
        val nextMonth = at(31, 13).apply { add(Calendar.DAY_OF_YEAR, 1) }
        assertEquals(nextMonth.timeInMillis, NoonBudgetReminder.nextNoon(endOfMonth))
    }

    @Test fun usesLocalTimezoneAndDoesNotMutateInput() {
        val jakartaNoon = at(6, 12).timeInMillis
        val now = Calendar.getInstance(TimeZone.getTimeZone("Asia/Makassar")).apply {
            timeInMillis = jakartaNoon
        }
        val original = now.timeInMillis
        val expected = (now.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 13)
        }
        assertEquals(expected.timeInMillis, NoonBudgetReminder.nextNoon(now))
        assertEquals(original, now.timeInMillis)
    }

    @Test fun onlyRemindsWhenExactlyZeroAtOrAfterOnePm() {
        assertFalse(NoonBudgetReminder.shouldNotify(0.0, 50000.0, at(6, 12, 59)))
        assertTrue(NoonBudgetReminder.shouldNotify(0.0, 50000.0, at(6, 13)))
        // Android may delay an inexact alarm.
        assertTrue(NoonBudgetReminder.shouldNotify(0.0, 50000.0, at(6, 14)))
        for (total in listOf(0.01, 25000.0, 37500.0, 50000.0, 62500.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertFalse(NoonBudgetReminder.shouldNotify(total, 50000.0, at(6, 13)))
        }
        for (limit in listOf(0.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertFalse(NoonBudgetReminder.shouldNotify(0.0, limit, at(6, 13)))
        }
        assertTrue(NoonBudgetReminder.message().body.contains("0%"))
        assertTrue(NoonBudgetReminder.message().body.contains("13.00"))
    }
}
