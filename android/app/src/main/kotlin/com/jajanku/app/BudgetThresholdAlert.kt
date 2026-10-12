package com.jajanku.app

object BudgetThresholdAlert {
    // A jump across several thresholds produces only the highest alert. Remembering
    // that threshold also prevents repeats after a deletion or a budget edit.
    fun nextThreshold(
        total: Double,
        limit: Double,
        date: String,
        lastDate: String?,
        lastThreshold: Int
    ): Int? {
        if (!total.isFinite() || total < 0 || !limit.isFinite() || limit <= 0) return null
        val threshold = when {
            total > limit -> 100
            total > limit * 0.75 -> 75
            total > limit * 0.5 -> 50
            else -> return null
        }
        val previous = if (date == lastDate) lastThreshold else 0
        return threshold.takeIf { it > previous }
    }
}
