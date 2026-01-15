package com.toleary.babyclock

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class WatchLifecycleService : WearableListenerService() {
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onMessageReceived(messageEvent: MessageEvent) {
        val detail = String(messageEvent.data)

        when (messageEvent.path) {
            "/log_feed" -> {
                scope.launch {
                    val timestamp = System.currentTimeMillis()
                    val event = BabyEvent(
                        type = "FEED",
                        subtype = "oz",
                        amountMl = detail.toFloatOrNull() ?: 0f,
                        timestamp = timestamp
                    )
                    BabyApplication.database.babyDao().insertEvent(event)

                    // Sync back to watch without using .await()
                    syncLastFeedToWatch(timestamp)
                }
            }
            "/log_diaper" -> {
                scope.launch {
                    val timestamp = System.currentTimeMillis()
                    val event = BabyEvent(
                        type = "DIAPER",
                        subtype = detail,
                        amountMl = 0f,
                        timestamp = timestamp
                    )
                    BabyApplication.database.babyDao().insertEvent(event)
                    syncLastFeedToWatch(timestamp)
                }
            }
        }
    }

    private fun syncLastFeedToWatch(timestamp: Long) {
        val dataClient = Wearable.getDataClient(this)
        val putDataReq = PutDataMapRequest.create("/last_feed").run {
            dataMap.putLong("timestamp", timestamp)
            dataMap.putLong("sync_time", System.currentTimeMillis())
            asPutDataRequest()
        }
        // By removing .await(), we remove the need for the broken import
        dataClient.putDataItem(putDataReq)
    }
}