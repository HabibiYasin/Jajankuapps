package com.jajanku.app

import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

object NoonBudgetReminder {
    data class Message(val title: String, val body: String)

    fun nextNoon(now: Calendar): Long = (now.clone() as Calendar).apply {
        set(Calendar.HOUR_OF_DAY, 12)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        if (timeInMillis <= now.timeInMillis) add(Calendar.DAY_OF_YEAR, 1)
    }.timeInMillis

    fun message(percent: Double, variant: Int): Message {
        require(percent.isFinite() && percent >= 0)
        val label = NumberFormat.getNumberInstance(Locale.forLanguageTag("id-ID")).apply {
            maximumFractionDigits = 1
        }.format(percent)
        val alternate = variant % 2 != 0
        return when {
            percent == 0.0 -> Message(
                if (alternate) "Sudah jajan siang ini?" else "Yuk, cek jajan hari ini!",
                "Belum ada pengeluaran budget tercatat hari ini (0%). Ketuk untuk catat jajanmu di Jajanku."
            )
            percent < 50 -> Message(
                if (alternate) "Budget masih lega!" else "Jajanmu masih terjaga",
                "$label% budget harian sudah terpakai. Ketuk untuk cek sisa budget sebelum jajan siang."
            )
            percent < 80 -> Message(
                if (alternate) "Cek dulu sebelum jajan lagi" else "Yuk, atur jajan sampai malam",
                "Sudah $label% budget harian terpakai. Ketuk untuk lihat pengeluaran dan rencanakan sisa hari ini."
            )
            percent < 100 -> Message(
                if (alternate) "Budget mulai menipis" else "Jajan siang, cek budget dulu!",
                "$label% budget harian sudah terpakai. Ketuk untuk cek sisanya dan pilih jajan yang pas."
            )
            percent == 100.0 -> Message(
                if (alternate) "Budget hari ini sudah penuh" else "Budget harian sudah terpakai",
                "Budget harianmu sudah terpakai 100%. Ketuk untuk lihat catatan dan atur pengeluaran berikutnya."
            )
            else -> Message(
                if (alternate) "Yuk, cek pengeluaran hari ini" else "Budget hari ini terlewati",
                "$label% budget harian sudah terpakai. Ketuk untuk lihat rinciannya dan rencanakan langkah berikutnya."
            )
        }
    }
}
