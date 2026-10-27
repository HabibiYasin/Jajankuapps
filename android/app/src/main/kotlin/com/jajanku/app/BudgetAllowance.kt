package com.jajanku.app

import java.util.Calendar
import java.util.Locale

/** Same completed-day calculation as BudgetLimits.dailyFor in Flutter. */
object BudgetAllowance {
    fun daily(monthly: Double, flexible: Boolean, date: Calendar, totals: Map<String, Number>): Double {
        val days = date.getActualMaximum(Calendar.DAY_OF_MONTH)
        var allowance = monthly / days
        if (!flexible) return allowance
        val year = date.get(Calendar.YEAR)
        val month = date.get(Calendar.MONTH) + 1
        for (day in 1 until date.get(Calendar.DAY_OF_MONTH)) {
            val key = String.format(Locale.US, "%04d-%02d-%02d", year, month, day)
            val excess = (totals[key]?.toDouble() ?: 0.0) - allowance
            if (excess > 0) allowance = (allowance - excess / (days - day)).coerceAtLeast(0.0)
        }
        return allowance
    }
}
