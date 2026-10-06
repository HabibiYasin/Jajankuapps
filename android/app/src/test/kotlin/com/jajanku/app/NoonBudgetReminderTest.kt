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

    @Test fun schedulesTodayBeforeNoonAndTomorrowAfterNoon() {
        assertEquals(at(6, 12).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 11, 59)))
        assertEquals(at(7, 12).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 12)))
        assertEquals(at(7, 12).timeInMillis, NoonBudgetReminder.nextNoon(at(6, 23)))
        assertEquals(at(7, 12).timeInMillis, NoonBudgetReminder.nextNoon(at(7, 0)))
    }

    @Test fun choosesMessagesAtEveryBudgetBoundaryAndInvitesOpeningTheApp() {
        for (percent in listOf(0.0, 25.0, 49.9, 50.0, 79.9, 80.0, 99.9, 100.0, 125.0)) {
            val message = NoonBudgetReminder.message(percent, 0)
            assertTrue(message.body.contains("Ketuk"))
            assertNotEquals(message.title, NoonBudgetReminder.message(percent, 1).title)
        }
        assertTrue(NoonBudgetReminder.message(0.0, 0).body.contains("Belum ada"))
        assertEquals("Jajanmu masih terjaga", NoonBudgetReminder.message(49.9, 0).title)
        assertEquals("Yuk, atur jajan sampai malam", NoonBudgetReminder.message(50.0, 0).title)
        assertEquals("Jajan siang, cek budget dulu!", NoonBudgetReminder.message(80.0, 0).title)
        assertEquals("Budget harian sudah terpakai", NoonBudgetReminder.message(100.0, 0).title)
        assertEquals("Budget hari ini terlewati", NoonBudgetReminder.message(125.0, 0).title)
        assertTrue(NoonBudgetReminder.message(125.0, 0).body.contains("125%"))
        assertTrue(NoonBudgetReminder.message(80.5, 0).body.contains("80,5%"))
    }
}
