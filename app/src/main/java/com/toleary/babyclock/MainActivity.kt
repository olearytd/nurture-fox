package com.toleary.babyclock

import android.app.NotificationChannel
import android.app.NotificationManager
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import com.toleary.babyclock.ui.theme.BabyClockTheme
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
                val tabs = listOf("Tracker", "Daily Log")

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
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
                        when (selectedTab) {
                            0 -> BabyClockScreen(
                                onLogEvent = { value, unit, category ->
                                    lifecycleScope.launch {
                                        val event = BabyEvent(
                                            type = category,
                                            subtype = unit,
                                            amountMl = value.toFloatOrNull() ?: 0f,
                                            timestamp = System.currentTimeMillis()
                                        )
                                        BabyApplication.database.babyDao().insertEvent(event)

                                        if (category == "FEED") {
                                            startBabyTimer(value)
                                        }
                                    }
                                }
                            )
                            1 -> DailyLogScreen(
                                onDeleteLatest = { stopBabyTimer() }
                            )
                        }
                    }
                }
            }
        }
    }

    private fun stopBabyTimer() {
        val intent = Intent(this, TimerService::class.java)
        stopService(intent)
    }

    private fun startBabyTimer(amount: String) {
        val intent = Intent(this, TimerService::class.java).apply {
            putExtra("START_TIME", System.currentTimeMillis())
            putExtra("FEED_AMOUNT", amount)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Baby Timer"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel("BABY_CHANNEL", name, importance)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BabyClockScreen(onLogEvent: (String, String, String) -> Unit) {
    var amountText by remember { mutableStateOf("") }
    var isOz by remember { mutableStateOf(true) }
    var showDiaperSheet by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = "Baby Clock", style = MaterialTheme.typography.headlineLarge)
        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = amountText,
            onValueChange = { amountText = it },
            label = { Text(if (isOz) "Amount (oz)" else "Amount (ml)") },
            modifier = Modifier.width(240.dp),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
        )

        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 8.dp)) {
            Text("mL")
            Switch(checked = isOz, onCheckedChange = { isOz = it }, modifier = Modifier.padding(horizontal = 8.dp))
            Text("Oz")
        }

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                onLogEvent(amountText, if (isOz) "oz" else "ml", "FEED")
                amountText = ""
            },
            modifier = Modifier.fillMaxWidth(0.7f)
        ) {
            Text("Log Feed & Start Timer")
        }

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = { showDiaperSheet = true },
            modifier = Modifier.fillMaxWidth(0.7f),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
        ) {
            Text("Log Diaper")
        }
    }

    if (showDiaperSheet) {
        ModalBottomSheet(onDismissRequest = { showDiaperSheet = false }) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Text("What type of diaper?", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(16.dp))
                listOf("Pee", "Poop", "Both").forEach { type ->
                    TextButton(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            onLogEvent("0", type, "DIAPER")
                            showDiaperSheet = false
                        }
                    ) {
                        Text(type, style = MaterialTheme.typography.bodyLarge)
                    }
                }
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DailyLogScreen(onDeleteLatest: () -> Unit) {
    val events by BabyApplication.database.babyDao().getAllEvents()
        .collectAsState(initial = emptyList())
    val scope = rememberCoroutineScope()

    // --- Goal & Summary State ---
    var dailyGoalOz by remember { mutableFloatStateOf(32f) }
    var showGoalDialog by remember { mutableStateOf(false) }

    val rawOz = events.filter { it.type == "FEED" && it.subtype == "oz" }.sumOf { it.amountMl.toDouble() }
    val rawMl = events.filter { it.type == "FEED" && it.subtype == "ml" }.sumOf { it.amountMl.toDouble() }

    val combinedTotalMl = (rawOz * 30.0) + rawMl
    val combinedTotalOz = (combinedTotalMl / 30.0).toFloat()
    val diaperCount = events.count { it.type == "DIAPER" }
    val progress = if (dailyGoalOz > 0) (combinedTotalOz / dailyGoalOz).coerceIn(0f, 1f) else 0f

    var editingEvent by remember { mutableStateOf<BabyEvent?>(null) }

    if (editingEvent != null) {
        EditFeedDialog(
            event = editingEvent!!,
            onDismiss = { editingEvent = null },
            onConfirm = { newAmountMl, newUnit ->
                scope.launch {
                    val updated = editingEvent!!.copy(amountMl = newAmountMl, subtype = newUnit)
                    BabyApplication.database.babyDao().updateEvent(updated)
                    editingEvent = null
                }
            }
        )
    }

    if (showGoalDialog) {
        AlertDialog(
            onDismissRequest = { showGoalDialog = false },
            title = { Text("Set Daily Goal (oz)") },
            text = {
                OutlinedTextField(
                    value = if (dailyGoalOz == 0f) "" else dailyGoalOz.toString(),
                    onValueChange = { dailyGoalOz = it.toFloatOrNull() ?: 0f },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )
            },
            confirmButton = { TextButton(onClick = { showGoalDialog = false }) { Text("Done") } }
        )
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(text = "Daily Summary", style = MaterialTheme.typography.headlineMedium)
            IconButton(onClick = { showGoalDialog = true }) {
                Icon(Icons.Default.Edit, contentDescription = "Edit Goal")
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    SummaryStat("Total Oz", "%.1f".format(combinedTotalOz))
                    SummaryStat("Total mL", "${combinedTotalMl.toInt()}")
                    SummaryStat("Diapers", "$diaperCount")
                }
                Spacer(modifier = Modifier.height(16.dp))
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxWidth().height(8.dp),
                    strokeCap = androidx.compose.ui.graphics.StrokeCap.Round
                )
                Text(
                    text = "${(progress * 100).toInt()}% of ${dailyGoalOz.toInt()}oz Goal",
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.align(Alignment.End).padding(top = 4.dp)
                )
            }
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

        LazyColumn(modifier = Modifier.fillMaxSize()) {
            items(items = events, key = { it.id }) { event ->
                val dismissState = rememberSwipeToDismissBoxState(
                    confirmValueChange = { direction ->
                        if (direction == SwipeToDismissBoxValue.EndToStart) {
                            scope.launch {
                                if (event == events.firstOrNull()) {
                                    onDeleteLatest()
                                }
                                BabyApplication.database.babyDao().deleteEvent(event)
                            }
                            true
                        } else false
                    }
                )

                SwipeToDismissBox(
                    state = dismissState,
                    enableDismissFromStartToEnd = false,
                    backgroundContent = {
                        val color = if (dismissState.dismissDirection == SwipeToDismissBoxValue.EndToStart) {
                            MaterialTheme.colorScheme.errorContainer
                        } else Color.Transparent
                        Box(
                            Modifier.fillMaxSize().background(color).padding(horizontal = 20.dp),
                            contentAlignment = Alignment.CenterEnd
                        ) {
                            Icon(Icons.Default.Delete, "Delete", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                ) {
                    Box(modifier = Modifier.padding(vertical = 4.dp).clickable {
                        if (event.type == "FEED") editingEvent = event
                    }) {
                        FeedingCard(event)
                    }
                }
            }
        }
    }
}

@Composable
fun SummaryStat(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.labelSmall)
        Text(value, style = MaterialTheme.typography.titleLarge)
    }
}

@Composable
fun EditFeedDialog(event: BabyEvent, onDismiss: () -> Unit, onConfirm: (Float, String) -> Unit) {
    // Standardizing to mL for precision editing (1oz = 30ml)
    val initialAmountMl = if (event.subtype == "oz") (event.amountMl * 30f) else event.amountMl

    // VISUAL FIX: Format to hide .0 but keep decimals if they exist (e.g. 105.5)
    val formattedInitialValue = if (initialAmountMl % 1.0f == 0.0f) {
        initialAmountMl.toInt().toString()
    } else {
        initialAmountMl.toString()
    }

    var amountText by remember { mutableStateOf(formattedInitialValue) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Amount (mL)") },
        text = {
            Column {
                Text("Editing in mL for higher precision", style = MaterialTheme.typography.bodySmall)
                OutlinedTextField(
                    value = amountText,
                    onValueChange = { amountText = it },
                    label = { Text("Amount (mL)") },
                    // This still allows the user to type a decimal if they want
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                )
            }
        },
        confirmButton = {
            Button(onClick = {
                val finalValue = amountText.toFloatOrNull() ?: initialAmountMl
                onConfirm(finalValue, "ml")
            }) {
                Text("Save as mL")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
fun FeedingCard(event: BabyEvent) {
    val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(event.timestamp))

    val displayAmount = if (event.amountMl % 1.0f == 0.0f) {
        event.amountMl.toInt().toString()
    } else {
        event.amountMl.toString()
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (event.type == "DIAPER")
                MaterialTheme.colorScheme.secondaryContainer
            else MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier.padding(16.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = if (event.type == "FEED") "Bottle Feed" else "Diaper",
                    style = MaterialTheme.typography.labelMedium
                )
                Text(
                    text = if (event.type == "FEED") "$displayAmount ${event.subtype}" else event.subtype,
                    style = MaterialTheme.typography.headlineSmall
                )
            }
            Text(text = time, style = MaterialTheme.typography.bodyMedium)
        }
    }
}