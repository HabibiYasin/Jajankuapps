package com.jajanku.app

import org.junit.Assert.*
import org.junit.Test

class BudgetThresholdAlertTest {
    private fun next(total: Double, last: Int = 0, lastDate: String? = "2026-10-12", limit: Double = 50000.0): Int? =
        BudgetThresholdAlert.nextThreshold(total, limit, "2026-10-12", lastDate, last)

    @Test fun alertsOnlyStrictlyAboveEachThreshold() {
        assertNull(next(0.0))
        assertNull(next(24999.0))
        assertNull(next(25000.0))
        assertEquals(50, next(25001.0))
        assertNull(next(37500.0, 50))
        assertEquals(75, next(37501.0, 50))
        assertNull(next(50000.0, 75))
        assertEquals(100, next(50001.0, 75))
    }

    @Test fun jumpsProduceOnlyHighestAlertAndDoNotRepeatAfterEditsOrSyncs() {
        assertEquals(75, next(40000.0))
        assertEquals(100, next(62500.0))
        assertNull(next(62500.0, 100))
        assertNull(next(30000.0, 100))
        assertNull(next(40000.0, 100))
        assertNull(next(90000.0, 100))
        assertNull(next(0.0, 100))
        assertNull(next(62500.0, 100))
    }

    @Test fun newDateResetsAlertsAndConfiguredLimitIsUsed() {
        assertEquals(50, next(30000.0, 100, "2026-10-11"))
        assertEquals(100, next(62500.0, 100, "2026-10-11"))
        assertEquals(50, next(30000.0, lastDate = null))
        assertEquals(75, next(40000.0, 50, limit = 45000.0))
        assertNull(next(40000.0, 75, limit = 100000.0))
    }

    @Test fun invalidTotalsAndLimitsNeverAlert() {
        for (total in listOf(-1.0, Double.NaN, Double.POSITIVE_INFINITY)) assertNull(next(total))
        for (limit in listOf(0.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertNull(next(62500.0, limit = limit))
        }
    }
}
