package com.toleary.babyclock.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import androidx.wear.compose.material.*
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import com.toleary.babyclock.presentation.theme.BabyClockTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.*

// Helper data class for dual-return
data class TimeDisplay(val text: String, val isOverdue: Boolean)

fun formatElapsedTime(lastFeedMs: Long): TimeDisplay {
    if (lastFeedMs == 0L) return TimeDisplay("--:--", false)

    val diffMs = System.currentTimeMillis() - lastFeedMs
    val totalMinutes = (diffMs / (1000 * 60)).toInt()
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60

    // RED warning if >= 3 hours
    val isOverdue = totalMinutes >= 180

    val text = when {
        hours > 0 -> "${hours}h ${minutes}m ago"
        else -> "${minutes}m ago"
    }
    return TimeDisplay(text, isOverdue)
}

class MainActivity : ComponentActivity(), DataClient.OnDataChangedListener {

    private var lastFeedTimestamp by mutableLongStateOf(0L)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setTheme(android.R.style.Theme_DeviceDefault)

        setContent {
            WearApp(
                lastFeedTime = lastFeedTimestamp,
                onLog = { type, detail ->
                    lifecycleScope.launch {
                        sendEventToPhone(type, detail)
                    }
                },
                onRefresh = { refreshLastFeedTime() }
            )
        }
    }

    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
        refreshLastFeedTime()
    }

    override fun onPause() {
        super.onPause()
        Wearable.getDataClient(this).removeListener(this)
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        try {
            dataEvents.forEach { event ->
                if (event.dataItem.uri.path == "/last_feed") {
                    val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                    lastFeedTimestamp = dataMap.getLong("timestamp")
                }
            }
        } finally {
            // Memory leak fix: Always release the buffer
            dataEvents.release()
        }
    }

    private fun refreshLastFeedTime() {
        lifecycleScope.launch {
            try {
                val dataItems = Wearable.getDataClient(this@MainActivity).dataItems.await()
                dataItems.forEach { item ->
                    if (item.uri.path == "/last_feed") {
                        val dataMap = DataMapItem.fromDataItem(item).dataMap
                        lastFeedTimestamp = dataMap.getLong("timestamp")
                    }
                }
            } catch (e: Exception) { }
        }
    }

    private suspend fun sendEventToPhone(type: String, detail: String) {
        try {
            val nodes = Wearable.getNodeClient(this).connectedNodes.await()
            for (node in nodes) {
                Wearable.getMessageClient(this)
                    .sendMessage(node.id, "/log_$type", detail.toByteArray())
                    .await()
            }
        } catch (e: Exception) {
            android.util.Log.e("BabyClockWatch", "Error: ${e.message}")
        }
    }
}

@Composable
fun WearApp(
    lastFeedTime: Long,
    onLog: (String, String) -> Unit,
    onRefresh: () -> Unit
) {
    BabyClockTheme {
        val listState = rememberScalingLazyListState()
        var activeMenu by remember { mutableStateOf("MAIN") }
        var selectedOz by remember { mutableStateOf(4) }
        var ticker by remember { mutableLongStateOf(System.currentTimeMillis()) }

        LaunchedEffect(Unit) {
            while (true) {
                delay(60_000)
                ticker = System.currentTimeMillis()
            }
        }

        LaunchedEffect(activeMenu) {
            if (activeMenu == "SUCCESS") {
                delay(2000)
                onRefresh()
                activeMenu = "MAIN"
            }
        }

        Scaffold(
            timeText = { if (activeMenu == "MAIN") TimeText() },
            vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
            positionIndicator = { PositionIndicator(scalingLazyListState = listState) }
        ) {
            when (activeMenu) {
                "MAIN" -> {
                    ScalingLazyColumn(
                        modifier = Modifier.fillMaxSize().background(MaterialTheme.colors.background),
                        state = listState,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        item { Text("Time Since Feed", style = MaterialTheme.typography.caption2) }
                        item {
                            val display = remember(lastFeedTime, ticker) {
                                formatElapsedTime(lastFeedTime)
                            }
                            Text(
                                text = display.text,
                                style = MaterialTheme.typography.title1,
                                fontWeight = FontWeight.Bold,
                                // Color changes to Red when overdue
                                color = if (display.isOverdue) Color.Red else MaterialTheme.colors.primary
                            )
                        }
                        item { Spacer(modifier = Modifier.height(8.dp)) }
                        item {
                            Chip(
                                onClick = { activeMenu = "FEED_PICKER" },
                                label = { Text("Log Feed") },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                        item {
                            Chip(
                                onClick = { activeMenu = "DIAPER_PICKER" },
                                label = { Text("Log Diaper") },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }

                "FEED_PICKER" -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Stepper(
                            value = selectedOz,
                            onValueChange = { selectedOz = it },
                            valueProgression = 1..15,
                            increaseIcon = { Icon(StepperDefaults.Increase, "More") },
                            decreaseIcon = { Icon(StepperDefaults.Decrease, "Less") }
                        ) {
                            Chip(
                                onClick = {
                                    onLog("feed", selectedOz.toString())
                                    activeMenu = "SUCCESS"
                                },
                                label = { Text("Confirm $selectedOz oz") },
                                colors = ChipDefaults.primaryChipColors(),
                                modifier = Modifier.width(110.dp)
                            )
                        }
                    }
                }

                "DIAPER_PICKER" -> {
                    ScalingLazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        item { Text("Diaper Type", style = MaterialTheme.typography.caption1) }
                        listOf("Pee", "Poop", "Both").forEach { diaperType ->
                            item {
                                Chip(
                                    onClick = {
                                        onLog("diaper", diaperType)
                                        activeMenu = "SUCCESS"
                                    },
                                    label = { Text(diaperType) },
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }
                    }
                }
                "SUCCESS" -> {
                    Column(
                        modifier = Modifier.fillMaxSize().background(MaterialTheme.colors.background),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(text = "✅", fontSize = 50.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Logged!", style = MaterialTheme.typography.title3)
                    }
                }
            }
        }
    }
}