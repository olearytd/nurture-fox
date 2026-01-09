package com.toleary.babyclock

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
import androidx.compose.ui.unit.sp
import java.util.concurrent.TimeUnit

class TimerWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val latestFeed = BabyApplication.database.babyDao().getLatestFeedSync()

        provideContent {
            GlanceTheme {
                Box(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .background(GlanceTheme.colors.primaryContainer)
                        .padding(8.dp)
                ) {
                    Column(
                        modifier = GlanceModifier
                            .fillMaxSize()
                            .clickable(actionStartActivity<MainActivity>()),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Last Feed",
                            style = TextStyle(fontSize = 12.sp, color = GlanceTheme.colors.onPrimaryContainer)
                        )

                        Text(
                            text = formatTimeAgo(latestFeed?.timestamp),
                            style = TextStyle(
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = GlanceTheme.colors.onPrimaryContainer
                            )
                        )
                    }

                    Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopEnd) {
                        Text(
                            text = "🔄",
                            modifier = GlanceModifier.clickable(actionRunCallback<RefreshCallback>()),
                            style = TextStyle(fontSize = 16.sp)
                        )
                    }
                }
            }
        }
    }
}

fun formatTimeAgo(timestamp: Long?): String {
    if (timestamp == null) return "No data"
    val diff = System.currentTimeMillis() - timestamp
    val hours = TimeUnit.MILLISECONDS.toHours(diff)
    val minutes = TimeUnit.MILLISECONDS.toMinutes(diff) % 60
    return if (hours > 0) "${hours}h ${minutes}m ago" else "${minutes}m ago"
}

class RefreshCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        TimerWidget().update(context, glanceId)
    }
}