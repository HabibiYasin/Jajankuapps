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
            if (call.method != "sync") {
                result.notImplemented()
            } else {
                try {
                    val limit = call.argument<Number>("dailyLimit")?.toDouble() ?: 0.0
                    val totals = call.argument<Map<String, Number>>("totals") ?: emptyMap()
                    BudgetNotification.save(this, limit, totals)
                    BudgetNotification.refresh(this)
                    val prefs = getSharedPreferences("budget_notification", MODE_PRIVATE)
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                        !prefs.getBoolean("permission_requested", false)) {
                        prefs.edit().putBoolean("permission_requested", true).apply()
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4201)
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("BUDGET_NOTIFICATION", error.message, null)
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4201) BudgetNotification.refresh(this)
    }
}
