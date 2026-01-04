package com.toleary.babyclock.complication

import androidx.wear.watchface.complications.data.*
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.*

class MainComplicationService : SuspendingComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        if (type != ComplicationType.SHORT_TEXT) return null
        return createComplicationData("2h")
    }

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
        val lastFeedTimestamp = getLastFeedFromDataLayer()

        // Calculate a simple string like "3h" or "45m" since last feed
        val displayStr = if (lastFeedTimestamp == 0L) "--" else {
            val diffMinutes = (System.currentTimeMillis() - lastFeedTimestamp) / 60000
            if (diffMinutes < 60) "${diffMinutes}m" else "${diffMinutes / 60}h"
        }

        return createComplicationData(displayStr)
    }

    private fun createComplicationData(text: String): ComplicationData {
        return ShortTextComplicationData.Builder(
            text = PlainComplicationText.Builder(text).build(),
            contentDescription = PlainComplicationText.Builder("Time since last feed").build()
        ).setMonochromaticImage(
            // You can add a small bottle icon here later!
            null
        ).build()
    }

    private suspend fun getLastFeedFromDataLayer(): Long {
        return try {
            val dataItems = Wearable.getDataClient(this).dataItems.await()
            dataItems.find { it.uri.path == "/last_feed" }?.let { item ->
                DataMapItem.fromDataItem(item).dataMap.getLong("timestamp")
            } ?: 0L
        } catch (e: Exception) { 0L }
    }
}