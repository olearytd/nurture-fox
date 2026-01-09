package com.toleary.babyclock

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class LogFeedCallback : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        // 1. Get the amount passed from the widget button
        val amount = parameters[AmountSmallKey] ?: parameters[AmountLargeKey] ?: "4"

        // 2. Perform background work
        CoroutineScope(Dispatchers.IO).launch {
            // Save the event to the database
            val event = BabyEvent(
                type = "FEED",
                subtype = "oz",
                amountMl = amount.toFloat(),
                timestamp = System.currentTimeMillis()
            )
            BabyApplication.database.babyDao().insertEvent(event)

            // 3. Reset the Timer Service
            // This mirrors the logic in MainActivity to ensure the notification/timer resets
            val timerIntent = Intent(context, TimerService::class.java).apply {
                putExtra("START_TIME", System.currentTimeMillis())
                putExtra("FEED_AMOUNT", amount)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(timerIntent)
            } else {
                context.startService(timerIntent)
            }

            // 4. Refresh ALL widgets so the "Time Since Last Feed" updates immediately
            TimerWidget().updateAll(context)
            ActionWidget().updateAll(context)
        }
    }
}