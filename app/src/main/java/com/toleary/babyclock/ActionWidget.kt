package com.toleary.babyclock

import android.content.Context
import androidx.compose.ui.unit.dp
import androidx.glance.Button
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*

// Define the key here so both the Widget and the Callback use the exact same reference
val AmountKey = ActionParameters.Key<String>("amount")

class ActionWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {

        // Fetch the user's preferred quick amount from SharedPreferences
        val prefs = context.getSharedPreferences("BabyClockPrefs", Context.MODE_PRIVATE)
        val prefAmount = prefs.getString("quick_amount", "4") ?: "4"

        provideContent {
            GlanceTheme {
                Row(
                    modifier = GlanceModifier.fillMaxSize().padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        text = "+${prefAmount}oz", // Dynamically labels the button
                        onClick = actionRunCallback<LogFeedCallback>(
                            actionParametersOf(AmountKey to prefAmount)
                        )
                    )
                    Spacer(GlanceModifier.width(8.dp))
                    Button(
                        text = "Diaper",
                        onClick = actionStartActivity<MainActivity>()
                    )
                }
            }
        }
    }
}