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

import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.unit.sp
import androidx.glance.background
import androidx.glance.text.Text

// Define keys for both buttons
val AmountSmallKey = ActionParameters.Key<String>("amount_small")
val AmountLargeKey = ActionParameters.Key<String>("amount_large")

class ActionWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("BabyClockPrefs", Context.MODE_PRIVATE)
        val smallAmount = prefs.getString("quick_amount_small", "2") ?: "2"
        val largeAmount = prefs.getString("quick_amount_large", "6") ?: "6"

        provideContent {
            GlanceTheme {
                // Use a Column to prevent text vertical-warping
                Column(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .background(GlanceTheme.colors.widgetBackground)
                        .padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Quick Log",
                        style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    )
                    Spacer(GlanceModifier.height(8.dp))

                    Row(modifier = GlanceModifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Button(
                            text = "+${smallAmount}oz",
                            onClick = actionRunCallback<LogFeedCallback>(
                                actionParametersOf(AmountSmallKey to smallAmount)
                            ),
                            modifier = GlanceModifier.defaultWeight()
                        )
                        Spacer(GlanceModifier.width(4.dp))
                        Button(
                            text = "+${largeAmount}oz",
                            onClick = actionRunCallback<LogFeedCallback>(
                                actionParametersOf(AmountLargeKey to largeAmount)
                            ),
                            modifier = GlanceModifier.defaultWeight()
                        )
                    }

                    Spacer(GlanceModifier.height(8.dp))

                    Button(
                        text = "Log Diaper",
                        onClick = actionStartActivity<MainActivity>(),
                        modifier = GlanceModifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}