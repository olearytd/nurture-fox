package com.toleary.babyclock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.window.core.layout.WindowWidthSizeClass
import androidx.glance.appwidget.updateAll
import androidx.lifecycle.lifecycleScope
import com.toleary.babyclock.ui.theme.BabyClockTheme
import com.patrykandpatrick.vico.compose.cartesian.CartesianChartHost
import com.patrykandpatrick.vico.compose.cartesian.axis.rememberBottomAxis
import com.patrykandpatrick.vico.compose.cartesian.axis.rememberStartAxis
import com.patrykandpatrick.vico.compose.cartesian.layer.rememberColumnCartesianLayer
import com.patrykandpatrick.vico.compose.cartesian.rememberCartesianChart
import com.patrykandpatrick.vico.core.cartesian.axis.AxisItemPlacer
import com.patrykandpatrick.vico.core.cartesian.data.CartesianChartModelProducer
import com.patrykandpatrick.vico.core.cartesian.data.columnSeries
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

        createNotificationChannel()

        setContent {
            BabyClockTheme {
                var selectedTab by remember { mutableIntStateOf(0) }
                val tabs = listOf("Tracker", "Daily Log", "Trends")

                val snackbarHostState = remember { SnackbarHostState() }
                val scope = rememberCoroutineScope()

                val adaptiveInfo = currentWindowAdaptiveInfo()
                val isExpanded = adaptiveInfo.windowSizeClass.windowWidthSizeClass == androidx.window.core.layout.WindowWidthSizeClass.EXPANDED

                Scaffold(
                    modifier = Modifier.fillMaxSize().safeDrawingPadding(),
                    containerColor = MaterialTheme.colorScheme.background,
                    snackbarHost = { SnackbarHost(snackbarHostState) },
                    bottomBar = {
                        TabRow(selectedTabIndex = selectedTab) {
                            tabs.forEachIndexed { index, title ->
                                Tab(
                                    selected = selectedTab == index,
                                    onClick = { selectedTab = index },
                                    text = { Text(title) }
                                )
                            }
                        }
                    }
                ) { innerPadding ->
                    Column(modifier = Modifier.padding(innerPadding)) {
                        if (isExpanded && selectedTab == 1) {
                            Row(Modifier.fillMaxSize()) {
                                Box(Modifier.weight(0.4f)) {
                                    DailyLogScreen(onDeleteLatest = { stopBabyTimer() })
                                }
                                VerticalDivider(thickness = 1.dp, color = MaterialTheme.colorScheme.outlineVariant)
                                Box(Modifier.weight(0.6f)) {
                                    TrendsScreen()
                                }
                            }
                        } else {
                            when (selectedTab) {
                                0 -> BabyClockScreen(
                                    onLogEvent = { value, unit, category, timestamp ->
                                        lifecycleScope.launch {
                                            val event = BabyEvent(
                                                type = category,
                                                subtype = unit,
                                                amountMl = value.toFloatOrNull() ?: 0f,
                                                timestamp = timestamp
                                            )
                                            BabyApplication.database.babyDao().insertEvent(event)
                                            if (category == "FEED") startBabyTimer(value, timestamp)
                                            scope.launch {
                                                snackbarHostState.showSnackbar("${category.lowercase().replaceFirstChar { it.uppercase() }} logged!")
                                            }
                                        }
                                    }
                                )
                                1 -> DailyLogScreen(onDeleteLatest = { stopBabyTimer() })
                                2 -> TrendsScreen()
                            }
                        }
                    }
                }
            }
        }
    }

    private fun startBabyTimer(amount: String, startTime: Long) {
        val intent = Intent(this, TimerService::class.java).apply {
            putExtra("START_TIME", startTime)
            putExtra("FEED_AMOUNT", amount)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
    }

    private fun stopBabyTimer() {
        val intent = Intent(this, TimerService::class.java)
        stopService(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("BABY_CHANNEL", "Baby Timer", NotificationManager.IMPORTANCE_DEFAULT)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BabyClockScreen(onLogEvent: (String, String, String, Long) -> Unit) {
    var amountText by remember { mutableStateOf("") }
    var isOz by remember { mutableStateOf(true) }
    var showDiaperSheet by remember { mutableStateOf(false) }
    val context = LocalContext.current

    var customTimestamp by remember { mutableStateOf<Long?>(null) }
    val displayTime = customTimestamp?.let { SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(it)) } ?: "Now"

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = "Nurture Fox", style = MaterialTheme.typography.headlineLarge, color = MaterialTheme.colorScheme.onBackground)
        Spacer(modifier = Modifier.height(24.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(" Logging for: ", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onBackground)
            TextButton(onClick = {
                val cal = Calendar.getInstance()
                TimePickerDialog(context, { _, h, m ->
                    val selected = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, h); set(Calendar.MINUTE, m) }
                    customTimestamp = selected.timeInMillis
                }, cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE), false).show()
            }) { Text(displayTime) }
            if (customTimestamp != null) {
                IconButton(onClick = { customTimestamp = null }) {
                    Icon(Icons.Default.Delete, "Reset", tint = MaterialTheme.colorScheme.error)
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        OutlinedTextField(value = amountText, onValueChange = { amountText = it }, label = { Text(if (isOz) "Amount (oz)" else "Amount (ml)") }, modifier = Modifier.width(240.dp), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 8.dp)) {
            Text("mL", color = MaterialTheme.colorScheme.onBackground); Switch(checked = isOz, onCheckedChange = { isOz = it }, modifier = Modifier.padding(horizontal = 8.dp)); Text("Oz", color = MaterialTheme.colorScheme.onBackground)
        }
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = {
            val logTime = customTimestamp ?: System.currentTimeMillis()
            onLogEvent(amountText, if (isOz) "oz" else "ml", "FEED", logTime)
            amountText = ""; customTimestamp = null
        }, modifier = Modifier.fillMaxWidth(0.7f)) { Text("Log Feed & Start Timer") }
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = { showDiaperSheet = true }, modifier = Modifier.fillMaxWidth(0.7f), colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)) { Text("Log Diaper") }
    }
    if (showDiaperSheet) {
        ModalBottomSheet(onDismissRequest = { showDiaperSheet = false }) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Text("What type of diaper?", style = MaterialTheme.typography.titleLarge); Spacer(modifier = Modifier.height(16.dp))
                listOf("Pee", "Poop", "Both").forEach { type ->
                    TextButton(modifier = Modifier.fillMaxWidth(), onClick = {
                        val logTime = customTimestamp ?: System.currentTimeMillis()
                        onLogEvent("0", type, "DIAPER", logTime)
                        showDiaperSheet = false; customTimestamp = null
                    }) { Text(type, style = MaterialTheme.typography.bodyLarge) }
                }
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DailyLogScreen(onDeleteLatest: () -> Unit) {
    val events by BabyApplication.database.babyDao().getAllEvents().collectAsState(initial = emptyList())
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current

    val prefs = remember { context.getSharedPreferences("BabyClockPrefs", Context.MODE_PRIVATE) }
    var dailyGoalOz by remember { mutableFloatStateOf(prefs.getFloat("daily_goal", 32f)) }

    var showGoalDialog by remember { mutableStateOf(false) }
    var editingEvent by remember { mutableStateOf<BabyEvent?>(null) }

    val todayStart = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
    val todayEvents = events.filter { it.timestamp >= todayStart }

    val rawOz = todayEvents.filter { it.type == "FEED" && it.subtype == "oz" }.sumOf { it.amountMl.toDouble() }
    val rawMl = todayEvents.filter { it.type == "FEED" && it.subtype == "ml" }.sumOf { it.amountMl.toDouble() }
    val combinedTotalOz = ((rawOz * 30.0 + rawMl) / 30.0).toFloat()
    val progress = if (dailyGoalOz > 0) (combinedTotalOz / dailyGoalOz).coerceIn(0f, 1f) else 0f

    val threeDaysAgo = todayStart - (2 * 24 * 60 * 60 * 1000L)
    val recentEvents = events.filter { it.timestamp >= threeDaysAgo }

    if (editingEvent != null) {
        EditEventDialog(event = editingEvent!!, onDismiss = { editingEvent = null }, onConfirm = { newAmount, newUnit, newTimestamp ->
            scope.launch { BabyApplication.database.babyDao().updateEvent(editingEvent!!.copy(amountMl = newAmount, subtype = newUnit, timestamp = newTimestamp)); editingEvent = null }
        })
    }

    if (showGoalDialog) {
        AlertDialog(onDismissRequest = { showGoalDialog = false }, title = { Text("Set Daily Goal (oz)") }, text = {
            OutlinedTextField(
                value = if (dailyGoalOz == 0f) "" else dailyGoalOz.toString(),
                onValueChange = {
                    val goal = it.toFloatOrNull() ?: 0f
                    dailyGoalOz = goal
                    prefs.edit().putFloat("daily_goal", goal).apply()
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
            )
        }, confirmButton = { TextButton(onClick = { showGoalDialog = false }) { Text("Done") } })
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(text = "Daily Summary", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onBackground)
            IconButton(onClick = { showGoalDialog = true }) { Icon(Icons.Default.Edit, contentDescription = null, tint = MaterialTheme.colorScheme.primary) }
        }
        Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    SummaryStat("Today's Oz", "%.1f".format(combinedTotalOz)); SummaryStat("Total mL", "${(combinedTotalOz * 30).toInt()}"); SummaryStat("Diapers", "${todayEvents.count { it.type == "DIAPER" }}")
                }
                Spacer(modifier = Modifier.height(16.dp)); LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth().height(8.dp), strokeCap = androidx.compose.ui.graphics.StrokeCap.Round)
                Text(text = "${(progress * 100).toInt()}% of ${dailyGoalOz.toInt()}oz Goal", style = MaterialTheme.typography.labelSmall, modifier = Modifier.align(Alignment.End).padding(top = 4.dp))
            }
        }
        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

        Text(text = "Recent History (3 Days)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)

        LazyColumn(modifier = Modifier.fillMaxSize()) {
            val groupedEvents = recentEvents.groupBy { SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(Date(it.timestamp)) }
            groupedEvents.forEach { (date, eventsInDay) ->
                item {
                    Text(text = date, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(vertical = 8.dp))
                    HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)
                }
                items(items = eventsInDay, key = { it.id }) { event ->
                    var showDeleteDialog by remember { mutableStateOf(false) }

                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = {
                            if (it == SwipeToDismissBoxValue.EndToStart) {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                showDeleteDialog = true
                                false
                            } else false
                        }
                    )

                    if (showDeleteDialog) {
                        AlertDialog(
                            onDismissRequest = {
                                showDeleteDialog = false
                                scope.launch { dismissState.reset() }
                            },
                            title = { Text("Delete Log?") },
                            text = { Text("Are you sure you want to delete this entry? This cannot be undone.") },
                            confirmButton = {
                                Button(onClick = {
                                    scope.launch {
                                        if (event == events.firstOrNull()) onDeleteLatest()
                                        BabyApplication.database.babyDao().deleteEvent(event)
                                        showDeleteDialog = false
                                    }
                                }, colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) {
                                    Text("Delete")
                                }
                            },
                            dismissButton = {
                                TextButton(onClick = {
                                    showDeleteDialog = false
                                    scope.launch { dismissState.reset() }
                                }) { Text("Cancel") }
                            }
                        )
                    }

                    SwipeToDismissBox(
                        state = dismissState,
                        enableDismissFromStartToEnd = false,
                        backgroundContent = {
                            val isSwiping = dismissState.targetValue == SwipeToDismissBoxValue.EndToStart
                            val backgroundColor = if (isSwiping) MaterialTheme.colorScheme.errorContainer else Color.Transparent

                            Box(Modifier.fillMaxSize().background(backgroundColor).padding(horizontal = 20.dp), contentAlignment = Alignment.CenterEnd) {
                                if (isSwiping) {
                                    Icon(Icons.Default.Delete, "Delete", tint = MaterialTheme.colorScheme.error)
                                }
                            }
                        }
                    ) {
                        Box(modifier = Modifier.padding(vertical = 4.dp).clickable { editingEvent = event }) { FeedingCard(event) }
                    }
                }
            }
        }
    }
}

@Composable
fun FeedingCard(event: BabyEvent) {
    val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(event.timestamp))
    fun formatValue(v: Float) = if (v % 1.0f == 0.0f) v.toInt().toString() else "%.1f".format(v)
    val displayString = if (event.type == "FEED") {
        if (event.subtype == "oz") "${formatValue(event.amountMl)} oz / ${(event.amountMl * 30).toInt()} ml" else "${formatValue(event.amountMl / 30f)} oz / ${formatValue(event.amountMl)} ml"
    } else event.subtype
    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = if (event.type == "DIAPER") MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceVariant)) {
        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Column {
                Text(text = if (event.type == "FEED") "Bottle Feed" else "Diaper", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(text = displayString, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
            }
            Text(text = time, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun EditEventDialog(event: BabyEvent, onDismiss: () -> Unit, onConfirm: (Float, String, Long) -> Unit) {
    val context = LocalContext.current
    var amountText by remember { mutableStateOf(event.amountMl.toString()) }
    val calendar = remember { Calendar.getInstance().apply { timeInMillis = event.timestamp } }
    var selectedTimeText by remember { mutableStateOf(SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(calendar.time)) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (event.type == "FEED") "Edit Feed" else "Edit Diaper") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (event.type == "FEED") OutlinedTextField(value = amountText, onValueChange = { amountText = it }, label = { Text("Amount") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
            Button(onClick = { TimePickerDialog(context, { _, h, m -> calendar.set(Calendar.HOUR_OF_DAY, h); calendar.set(Calendar.MINUTE, m); selectedTimeText = SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(calendar.time) }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), false).show() }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.Edit, null, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("Time: $selectedTimeText")
            }
        }
    }, confirmButton = { Button(onClick = { onConfirm(amountText.toFloatOrNull() ?: event.amountMl, event.subtype, calendar.timeInMillis) }) { Text("Save") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } })
}

@Composable
fun SummaryStat(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
        Text(value, style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
    }
}

@Composable
fun TrendsScreen() {
    val events by BabyApplication.database.babyDao().getAllEvents().collectAsState(initial = emptyList())

    val calendar = Calendar.getInstance()
    val now = calendar.timeInMillis

    calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0); calendar.set(Calendar.SECOND, 0)
    val startOfToday = calendar.timeInMillis
    val timeElapsedToday = now - startOfToday

    val startOfYesterday = startOfToday - (24 * 60 * 60 * 1000L)
    val endOfYesterdayPeriod = startOfYesterday + timeElapsedToday

    val todayEvents = events.filter { it.timestamp in startOfToday..now }
    val yesterdayPeriodEvents = events.filter { it.timestamp in startOfYesterday..endOfYesterdayPeriod }

    val todayVol = todayEvents.filter { it.type == "FEED" }.sumOf { if(it.subtype == "oz") it.amountMl.toDouble() else it.amountMl / 30.0 }
    val yesterdayVol = yesterdayPeriodEvents.filter { it.type == "FEED" }.sumOf { if(it.subtype == "oz") it.amountMl.toDouble() else it.amountMl / 30.0 }

    val feedingEvents = events.filter { it.type == "FEED" }
    val diaperEvents = events.filter { it.type == "DIAPER" }
    val dayCount = events.groupBy { SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(it.timestamp)) }.size.coerceAtLeast(1)
    val totalOz = feedingEvents.sumOf { if (it.subtype == "oz") (it.amountMl * 30.0) else it.amountMl.toDouble() } / 30.0

    val sevenDaysAgo = now - (7 * 24 * 60 * 60 * 1000L)
    val modelProducer24h = remember { CartesianChartModelProducer.build() }
    val modelProducer7d = remember { CartesianChartModelProducer.build() }

    LaunchedEffect(events) {
        modelProducer24h.tryRunTransaction {
            columnSeries {
                val entryList = mutableListOf<Float>()
                val startOfLast24h = now - (24 * 60 * 60 * 1000L)
                for (i in 0..7) {
                    val s = startOfLast24h + (i * 3 * 60 * 60 * 1000L); val e = s + (3 * 60 * 60 * 1000L)
                    entryList.add(feedingEvents.filter { it.timestamp in s until e }.sumOf { if (it.subtype == "oz") it.amountMl.toDouble() else (it.amountMl / 30.0) }.toFloat())
                }
                series(entryList)
            }
        }
        modelProducer7d.tryRunTransaction {
            columnSeries {
                val dailyTotals = mutableListOf<Float>()
                for (i in 0..6) {
                    val dayStart = sevenDaysAgo + (i * 24 * 60 * 60 * 1000L); val dayEnd = dayStart + (24 * 60 * 60 * 1000L)
                    dailyTotals.add(feedingEvents.filter { it.timestamp in dayStart until dayEnd }.sumOf { if (it.subtype == "oz") it.amountMl.toDouble() else (it.amountMl / 30.0) }.toFloat())
                }
                series(dailyTotals)
            }
        }
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState())) {
        Text("Trends & Habits", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onBackground)
        Spacer(modifier = Modifier.height(16.dp))

        StatCategoryCard("Previous Day Comparison") {
            Text("Today vs Yesterday (up to ${SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(now))})", style = MaterialTheme.typography.labelSmall)
            Spacer(Modifier.height(8.dp))
            StatRow("Vol Today", "%.1f oz".format(todayVol))
            StatRow("Vol Yesterday", "%.1f oz".format(yesterdayVol))

            val volDiff = todayVol - yesterdayVol
            Text(
                text = if (volDiff >= 0) "+%.1f oz vs yesterday".format(volDiff) else "%.1f oz vs yesterday".format(volDiff),
                color = if (volDiff >= 0) Color(0xFF4CAF50) else Color(0xFFF44336),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold
            )
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            StatRow("Diapers Today", "${todayEvents.count { it.type == "DIAPER" }}")
            StatRow("Diapers Yesterday", "${yesterdayPeriodEvents.count { it.type == "DIAPER" }}")
        }

        Spacer(modifier = Modifier.height(16.dp))
        ChartCard("Volume (oz) - Last 24h", modelProducer24h)
        Spacer(modifier = Modifier.height(16.dp))
        ChartCard("Daily Volume (oz) - Last 7 Days", modelProducer7d)
        Spacer(modifier = Modifier.height(16.dp))

        StatCategoryCard("Historical Summary") {
            val last7d = now - (7 * 24 * 60 * 60 * 1000L)
            val last14d = now - (14 * 24 * 60 * 60 * 1000L)
            val last30d = now - (30 * 24 * 60 * 60 * 1000L)

            fun getVol(since: Long) = feedingEvents.filter { it.timestamp >= since }.sumOf { if(it.subtype == "oz") it.amountMl.toDouble() else it.amountMl / 30.0 }

            StatRow("Last 7 Days Total", "%.0f oz".format(getVol(last7d)))
            StatRow("Last 14 Days Total", "%.0f oz".format(getVol(last14d)))
            StatRow("Last 30 Days Total", "%.0f oz".format(getVol(last30d)))
        }

        Spacer(modifier = Modifier.height(16.dp))
        StatCategoryCard("Feeding Patterns") {
            StatRow("Daily Average", "%.1f oz".format(totalOz / dayCount))
            StatRow("Bottles per Day", "%.1f".format(feedingEvents.size.toFloat() / dayCount))
            StatRow("Avg. per Bottle", "%.1f oz".format(if(feedingEvents.isNotEmpty()) totalOz/feedingEvents.size else 0.0))
        }

        Spacer(modifier = Modifier.height(16.dp))

        StatCategoryCard("Diaper History") {
            StatRow("Total Changes", "${diaperEvents.size}")
            StatRow("Daily Average", "%.1f".format(diaperEvents.size.toFloat() / dayCount))
            StatRow("Total Pees", "${diaperEvents.count { it.subtype == "Pee" || it.subtype == "Both" }}")
            StatRow("Total Poops", "${diaperEvents.count { it.subtype == "Poop" || it.subtype == "Both" }}")
        }

        Spacer(modifier = Modifier.height(16.dp))
        StatCategoryCard("Intervals") {
            val sortedFeeds = feedingEvents.sortedBy { it.timestamp }
            if (sortedFeeds.size > 1) {
                val spanHrs = (sortedFeeds.last().timestamp - sortedFeeds.first().timestamp) / (1000.0 * 60 * 60)
                StatRow("Avg. Time Between Feeds", "%.1f hours".format(spanHrs / (sortedFeeds.size - 1)))
            } else {
                Text("Log more feeds to see intervals", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
fun ChartCard(title: String, modelProducer: CartesianChartModelProducer) {
    Card(modifier = Modifier.fillMaxWidth().height(220.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            CartesianChartHost(chart = rememberCartesianChart(rememberColumnCartesianLayer(), startAxis = rememberStartAxis(itemPlacer = AxisItemPlacer.Vertical.count(count = { 5 }), valueFormatter = { value, _, _ -> "${value.toInt()}oz" }), bottomAxis = rememberBottomAxis(valueFormatter = { _, _, _ -> "" })), modelProducer = modelProducer, modifier = Modifier.fillMaxSize())
        }
    }
}

@Composable
fun StatCategoryCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.outlineVariant)
            content()
        }
    }
}

@Composable
fun StatRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
    }
}