package com.jajanku.app

import java.util.Calendar

object NoonBudgetReminder {
    data class Message(val title: String, val body: String)

    fun nextNoon(now: Calendar): Long = (now.clone() as Calendar).apply {
        set(Calendar.HOUR_OF_DAY, 13)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        if (timeInMillis <= now.timeInMillis) add(Calendar.DAY_OF_YEAR, 1)
    }.timeInMillis

    fun shouldNotify(total: Double, limit: Double, now: Calendar): Boolean =
        total == 0.0 && limit.isFinite() && limit > 0 && now.get(Calendar.HOUR_OF_DAY) >= 13

    fun message(): Message = Message(
        "Sudah jajan siang ini?",
        "Sudah pukul 13.00, budget harianmu masih 0%. Belum ada pengeluaran budget tercatat hari ini. Ketuk untuk catat jajanmu di Jajanku."
    )
}
