package com.jajanku.app

import java.util.Calendar
import org.junit.Assert.*
import org.junit.Test

class BudgetAllowanceTest {
    private fun date(year: Int, month: Int, day: Int) = Calendar.getInstance().apply {
        clear()
        set(year, month - 1, day)
    }

    @Test fun overspendChangesTomorrowAndWeeklyEquivalent() {
        val totals = mapOf("2026-11-10" to 100000.0)
        assertEquals(50000.0, BudgetAllowance.daily(1500000.0, true, date(2026, 11, 10), totals), 0.001)
        assertEquals(47500.0, BudgetAllowance.daily(1500000.0, true, date(2026, 11, 11), totals), 0.001)
        assertEquals(50000.0, BudgetAllowance.daily(1500000.0, false, date(2026, 11, 11), totals), 0.001)
        assertEquals(47500.0 - 12500.0 / 19, BudgetAllowance.daily(1500000.0, true, date(2026, 11, 12),
            totals + ("2026-11-11" to 60000.0)), 0.001)
    }

    @Test fun depletionResetsAndCalendarLengthHandlesLeapYears() {
        val totals = mapOf("2026-11-10" to 2000000.0)
        assertEquals(0.0, BudgetAllowance.daily(1500000.0, true, date(2026, 11, 11), totals), 0.001)
        assertEquals(1500000.0 / 31, BudgetAllowance.daily(1500000.0, true, date(2026, 12, 1), totals), 0.001)
        assertEquals(1500000.0 / 28, BudgetAllowance.daily(1500000.0, true, date(2026, 2, 1), totals), 0.001)
        assertEquals(1500000.0 / 29, BudgetAllowance.daily(1500000.0, true, date(2028, 2, 1), totals), 0.001)
    }
}
