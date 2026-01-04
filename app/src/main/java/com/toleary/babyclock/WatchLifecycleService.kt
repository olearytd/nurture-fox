package com.toleary.babyclock

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class WatchLifecycleService : WearableListenerService() {
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == "/log_feed") {
            scope.launch {
                val lastAmount = getSharedPreferences("BabyClockPrefs", MODE_PRIVATE)
                    .getString("quick_amount_small", "4") ?: "4"

                val event = BabyEvent(
                    type = "FEED",
                    subtype = "oz",
                    amountMl = lastAmount.toFloat(),
                    timestamp = System.currentTimeMillis()
                )
                BabyApplication.database.babyDao().insertEvent(event)
            }
        }
    }
}