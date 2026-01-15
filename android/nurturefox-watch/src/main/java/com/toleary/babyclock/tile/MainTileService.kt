package com.toleary.babyclock.tile

import androidx.wear.tiles.TileService
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.RequestBuilders
// Use this specific resource builder to satisfy the return type
import androidx.wear.tiles.ResourceBuilders as TilesResources

import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.TimelineBuilders

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.guava.future
import com.google.common.util.concurrent.ListenableFuture

import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.DataMapItem
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.*

class MainTileService : TileService() {

    private val serviceJob = Job()
    private val manualScope = CoroutineScope(Dispatchers.IO + serviceJob)

    override fun onDestroy() {
        super.onDestroy()
        serviceJob.cancel()
    }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile?> {
        return manualScope.future {
            val timestamp = getLastFeedTimestamp()

            TileBuilders.Tile.Builder()
                .setResourcesVersion("1.0")
                .setTileTimeline(
                    TimelineBuilders.Timeline.Builder().addTimelineEntry(
                        TimelineBuilders.TimelineEntry.Builder().setLayout(
                            LayoutElementBuilders.Layout.Builder().setRoot(
                                createLayout(timestamp)
                            ).build()
                        ).build()
                    ).build()
                ).build()
        }
    }

    private suspend fun getLastFeedTimestamp(): Long {
        return try {
            val dataItems = Wearable.getDataClient(this).dataItems.await()
            var timestamp = 0L
            dataItems.forEach { item ->
                if (item.uri.path == "/last_feed") {
                    timestamp = DataMapItem.fromDataItem(item).dataMap.getLong("timestamp")
                }
            }
            timestamp
        } catch (e: Exception) { 0L }
    }

    private fun createLayout(timestamp: Long): LayoutElementBuilders.LayoutElement {
        val timeLabel = if (timestamp == 0L) "--:--"
        else SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(timestamp))

        return LayoutElementBuilders.Column.Builder()
            .addContent(LayoutElementBuilders.Text.Builder().setText("Last Feed").build())
            .addContent(LayoutElementBuilders.Text.Builder().setText(timeLabel).build())
            .build()
    }

    // Explicitly returning the older TilesResources to match the service contract
    override fun onResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<androidx.wear.tiles.ResourceBuilders.Resources?> {
        return manualScope.future {
            TilesResources.Resources.Builder()
                .setVersion("1.0")
                .build()
        }
    }
}