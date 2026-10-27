package com.jajanku.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.os.Build
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.jajanku.app/budget_notification").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getEnabled" -> result.success(BudgetNotification.isEnabled(this))
                    "getThresholdEnabled" -> result.success(BudgetNotification.isThresholdEnabled(this))
                    "setThresholdEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled")
                            ?: throw IllegalArgumentException("Pilihan peringatan tidak valid")
                        BudgetNotification.setThresholdEnabled(this, enabled)
                        if (enabled) requestBudgetNotificationPermission(explicit = true)
                        result.success(null)
                    }
                    "getNoonEnabled" -> result.success(BudgetNotification.isNoonEnabled(this))
                    "setNoonEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled")
                            ?: throw IllegalArgumentException("Pilihan pengingat tidak valid")
                        BudgetNotification.setNoonEnabled(this, enabled)
                        if (enabled) requestBudgetNotificationPermission(explicit = true)
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled")
                            ?: throw IllegalArgumentException("Pilihan notifikasi tidak valid")
                        BudgetNotification.setEnabled(this, enabled)
                        if (enabled) requestBudgetNotificationPermission(explicit = true)
                        result.success(null)
                    }
                    "sync" -> {
                        val limit = call.argument<Number>("dailyLimit")?.toDouble() ?: 0.0
                        val totals = call.argument<Map<String, Number>>("totals") ?: emptyMap()
                        val monthly = call.argument<Number>("monthlyBudget")?.toDouble()
                        val flexible = call.argument<Boolean>("flexible") ?: false
                        BudgetNotification.save(this, limit, totals, monthly, flexible)
                        BudgetNotification.refresh(this)
                        requestBudgetNotificationPermission()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("BUDGET_NOTIFICATION", error.message, null)
            }
        }
    }

    private fun requestBudgetNotificationPermission(explicit: Boolean = false) {
        val prefs = getSharedPreferences("budget_notification", MODE_PRIVATE)
        if ((BudgetNotification.isEnabled(this) || BudgetNotification.isNoonEnabled(this) ||
                BudgetNotification.isThresholdEnabled(this)) && Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
            (explicit || !prefs.getBoolean("permission_requested", false))) {
            prefs.edit().putBoolean("permission_requested", true).apply()
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4201)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4201) BudgetNotification.refresh(this)
    }
}
