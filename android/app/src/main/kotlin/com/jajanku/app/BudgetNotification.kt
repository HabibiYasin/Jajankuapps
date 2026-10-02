package com.jajanku.app

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object BudgetNotification {
    private const val CHANNEL = "daily_budget_progress"
    private const val ID = 4201

    fun save(context: Context, limit: Double, totals: Map<String, Number>) {
        require(limit.isFinite() && limit > 0) { "Budget harus lebih dari nol" }
        require(totals.values.all { it.toDouble().isFinite() })
        // Commit before replying to Flutter so restoration survives process death.
        check(context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
            .edit().putFloat("limit", limit.toFloat())
            .putString("totals", JSONObject(totals).toString()).commit())
    }

    fun refresh(context: Context) {
        val prefs = context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
        if (!prefs.contains("totals")) return
        scheduleMidnight(context)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL,
                "Progres budget harian", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Pengeluaran hari ini dibandingkan dengan batas budget harian"
                setSound(null, null)
                enableVibration(false)
            })
        }
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
        val total = JSONObject(prefs.getString("totals", "{}") ?: "{}").optDouble(date, 0.0)
        val limit = prefs.getFloat("limit", 50000f).toDouble()
        val percent = total / limit * 100
        val color = Color.parseColor(when {
            percent >= 100 -> "#E53935"
            percent >= 80 -> "#F9A825"
            else -> "#00897B"
        })
        val money = NumberFormat.getIntegerInstance(Locale.forLanguageTag("id-ID"))
        // Only the visual bar is capped; the label keeps the actual percentage.
        val percentLabel = NumberFormat.getNumberInstance(Locale.forLanguageTag("id-ID")).apply {
            maximumFractionDigits = 1
        }.format(percent)
        val title = "Rp${money.format(total)} / Rp${money.format(limit)}"
        val text = "$percentLabel% budget harian terpakai"
        val bitmap = Bitmap.createBitmap(600, 8, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.parseColor("#55808080")
        canvas.drawRoundRect(0f, 0f, 600f, 8f, 4f, 4f, paint)
        paint.color = color
        canvas.drawRoundRect(0f, 0f, (percent.coerceIn(0.0, 100.0) * 6).toFloat(), 8f, 4f, 4f, paint)
        val views = RemoteViews(context.packageName, R.layout.notification_budget).apply {
            setTextViewText(R.id.budget_title, title)
            setTextViewText(R.id.budget_percent, text)
            setTextColor(R.id.budget_percent, color)
            setImageViewBitmap(R.id.budget_progress, bitmap)
        }
        val open = PendingIntent.getActivity(context, ID,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val restore = PendingIntent.getBroadcast(context, ID,
            Intent(context, BudgetNotificationReceiver::class.java).setAction("com.jajanku.app.RESTORE_BUDGET"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
            else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_budget_notification)
            .setContentTitle(title).setContentText(text).setColor(color)
            .setContentIntent(open).setDeleteIntent(restore)
            .setOngoing(true).setAutoCancel(false).setOnlyAlertOnce(true)
            .setShowWhen(false).setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
        if (Build.VERSION.SDK_INT >= 24) {
            builder.setStyle(Notification.DecoratedCustomViewStyle())
                .setCustomContentView(views).setCustomBigContentView(views)
        } else {
            builder.setContent(views)
        }
        manager.notify(ID, builder.build())
    }

    private fun scheduleMidnight(context: Context) {
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val intent = PendingIntent.getBroadcast(context, ID + 1,
            Intent(context, BudgetNotificationReceiver::class.java).setAction("com.jajanku.app.BUDGET_NEW_DAY"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        // Inexact alarm: no exact-alarm permission or always-running service needed.
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, intent)
    }
}

class BudgetNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        BudgetNotification.refresh(context)
    }
}
