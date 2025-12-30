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
        provideContent {
            GlanceTheme {
                Row(
                    modifier = GlanceModifier.fillMaxSize().padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        text = "+4oz",
                        onClick = actionRunCallback<LogFeedCallback>(
                            actionParametersOf(AmountKey to "4")
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