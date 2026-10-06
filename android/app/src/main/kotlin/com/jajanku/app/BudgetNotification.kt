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
    private const val NOON_ID = 4203
    private const val NOON_CHANNEL = "daily_budget_noon_reminder"
    const val NOON_ACTION = "com.jajanku.app.BUDGET_NOON"

    fun isNoonEnabled(context: Context): Boolean =
        context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
            .getBoolean("noon_enabled", true)

    fun setNoonEnabled(context: Context, enabled: Boolean) {
        check(context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
            .edit().putBoolean("noon_enabled", enabled).commit())
        scheduleNoon(context)
    }

    fun scheduleNoon(context: Context, force: Boolean = false) {
        val prefs = context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val broadcast = Intent(context, BudgetNotificationReceiver::class.java).setAction(NOON_ACTION)
        val existing = PendingIntent.getBroadcast(context, NOON_ID, broadcast,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (!isNoonEnabled(context) || !prefs.contains("totals")) {
            if (existing != null) {
                manager.cancel(existing)
                existing.cancel()
            }
            prefs.edit().remove("noon_scheduled_at").apply()
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOON_ID)
            return
        }
        val now = Calendar.getInstance()
        val scheduled = prefs.getLong("noon_scheduled_at", 0)
        val scheduledDate = Calendar.getInstance().apply { timeInMillis = scheduled }
        // Keep today's delayed alarm when a transaction sync happens just after noon.
        if (!force && existing != null && scheduled > 0 &&
            (scheduled > now.timeInMillis ||
                (scheduledDate.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
                 scheduledDate.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)))) return
        val next = NoonBudgetReminder.nextNoon(now)
        val alarm = PendingIntent.getBroadcast(context, NOON_ID, broadcast,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarm)
        prefs.edit().putLong("noon_scheduled_at", next).apply()
    }

    fun showNoon(context: Context) {
        scheduleNoon(context, force = true)
        if (!isNoonEnabled(context)) return
        val prefs = context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
        if (!prefs.contains("totals")) return
        val now = Calendar.getInstance()
        if (now.get(Calendar.HOUR_OF_DAY) < 12) return
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
        if (prefs.getString("last_noon_date", null) == date) return
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(NOON_CHANNEL,
                "Pengingat budget jam 12", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Pengingat siang berdasarkan persentase budget harian yang terpakai"
            })
            if (manager.getNotificationChannel(NOON_CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return
        }
        val total = JSONObject(prefs.getString("totals", "{}") ?: "{}").optDouble(date, 0.0)
        val limit = prefs.getFloat("limit", 50000f).toDouble()
        if (!total.isFinite() || total < 0 || !limit.isFinite() || limit <= 0) return
        val message = NoonBudgetReminder.message(total / limit * 100, now.get(Calendar.DAY_OF_YEAR))
        val open = PendingIntent.getActivity(context, NOON_ID,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, NOON_CHANNEL)
            else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_budget_notification)
            .setContentTitle(message.title).setContentText(message.body)
            .setStyle(Notification.BigTextStyle().bigText(message.body))
            .setContentIntent(open).setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(R.drawable.ic_budget_notification, "Buka Jajanku", open).build())
        manager.notify(NOON_ID, builder.build())
        prefs.edit().putString("last_noon_date", date).apply()
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
            .getBoolean("enabled", true)

    fun setEnabled(context: Context, enabled: Boolean) {
        check(context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
            .edit().putBoolean("enabled", enabled).commit())
        refresh(context)
    }

    private fun cancel(context: Context) {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ID)
        val alarm = PendingIntent.getBroadcast(context, ID + 1,
            Intent(context, BudgetNotificationReceiver::class.java).setAction("com.jajanku.app.BUDGET_NEW_DAY"),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (alarm != null) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(alarm)
            alarm.cancel()
        }
    }

    fun save(context: Context, limit: Double, totals: Map<String, Number>) {
        require(limit.isFinite() && limit > 0) { "Budget harus lebih dari nol" }
        require(totals.values.all { it.toDouble().isFinite() })
        // Commit before replying to Flutter so restoration survives process death.
        check(context.getSharedPreferences("budget_notification", Context.MODE_PRIVATE)
            .edit().putFloat("limit", limit.toFloat())
            .putString("totals", JSONObject(totals).toString()).commit())
    }

    fun refresh(context: Context, rescheduleNoon: Boolean = false) {
        scheduleNoon(context, force = rescheduleNoon)
        if (!isEnabled(context)) {
            cancel(context)
            return
        }
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
        if (intent.action == BudgetNotification.NOON_ACTION) {
            BudgetNotification.showNoon(context)
        } else {
            BudgetNotification.refresh(context, rescheduleNoon = intent.action in listOf(
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED))
        }
    }
}
