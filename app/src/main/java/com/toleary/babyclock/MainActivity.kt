package com.toleary.babyclock

import android.app.DatePickerDialog
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.updateAll
import androidx.window.core.layout.WindowWidthSizeClass
import androidx.lifecycle.lifecycleScope
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.toleary.babyclock.ui.theme.BabyClockTheme
import com.patrykandpatrick.vico.compose.cartesian.*
import com.patrykandpatrick.vico.compose.cartesian.axis.*
import com.patrykandpatrick.vico.compose.cartesian.layer.*
import com.patrykandpatrick.vico.core.cartesian.axis.AxisItemPlacer
import com.patrykandpatrick.vico.core.cartesian.data.CartesianChartModelProducer
import com.patrykandpatrick.vico.core.cartesian.data.columnSeries
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

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

        val widgetRequest = PeriodicWorkRequestBuilder<WidgetWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "widget_heartbeat",
            ExistingPeriodicWorkPolicy.KEEP,
            widgetRequest
        )

        setContent {
            val context = LocalContext.current
            val prefs = remember { context.getSharedPreferences("BabyClockPrefs", Context.MODE_PRIVATE) }

            var themePreference by remember { mutableIntStateOf(prefs.getInt("theme_pref", 0)) }
            val useDarkTheme = when(themePreference) {
                1 -> false
                2 -> true
                else -> isSystemInDarkTheme()
            }

            var showWalkthrough by remember { mutableStateOf(prefs.getBoolean("show_walkthrough_v1", true)) }

            BabyClockTheme(darkTheme = useDarkTheme) {
                var selectedTab by remember { mutableIntStateOf(0) }
                val tabs = listOf("Tracker", "Daily Log", "Trends", "Milestones")
                val snackbarHostState = remember { SnackbarHostState() }
                val scope = rememberCoroutineScope()

                var showSettings by remember { mutableStateOf(false) }
                var babyName by remember { mutableStateOf(prefs.getString("baby_name", "Nurture Fox") ?: "Nurture Fox") }
                var babyBirthDate by remember { mutableLongStateOf(prefs.getLong("baby_birthday", 0L)) }

                val adaptiveInfo = currentWindowAdaptiveInfo()
                val isExpanded = adaptiveInfo.windowSizeClass.windowWidthSizeClass == WindowWidthSizeClass.EXPANDED

                if (showWalkthrough) {
                    WalkthroughDialog(onDismiss = {
                        showWalkthrough = false
                        prefs.edit().putBoolean("show_walkthrough_v1", false).apply()
                    })
                }

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    containerColor = MaterialTheme.colorScheme.background,
                    snackbarHost = { SnackbarHost(snackbarHostState) },
                    topBar = {
                        @OptIn(ExperimentalMaterial3Api::class)
                        CenterAlignedTopAppBar(
                            title = { Text(babyName) },
                            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                                containerColor = Color.Transparent,
                                titleContentColor = MaterialTheme.colorScheme.onBackground
                            ),
                            actions = {
                                IconButton(onClick = { showSettings = true }) {
                                    Icon(Icons.Default.Settings, contentDescription = "Settings")
                                }
                            }
                        )
                    },
                    bottomBar = {
                        NavigationBar(
                            containerColor = Color.Transparent,
                            modifier = Modifier.windowInsetsPadding(WindowInsets.navigationBars)
                        ) {
                            tabs.forEachIndexed { index, title ->
                                NavigationBarItem(
                                    selected = selectedTab == index,
                                    onClick = { selectedTab = index },
                                    label = { Text(title) },
                                    icon = {
                                        Icon(
                                            imageVector = when(index) {
                                                0 -> Icons.Default.Timer
                                                1 -> Icons.AutoMirrored.Filled.List
                                                2 -> Icons.Default.Timeline
                                                3 -> Icons.Default.Stars
                                                else -> Icons.Default.Timer
                                            },
                                            contentDescription = null
                                        )
                                    }
                                )
                            }
                        }
                    }
                ) { innerPadding ->
                    if (showSettings) {
                        SettingsDialog(
                            currentName = babyName,
                            currentBirthday = babyBirthDate,
                            currentTheme = themePreference,
                            onThemeChange = { themePreference = it },
                            onShowWalkthrough = {
                                showSettings = false
                                showWalkthrough = true
                            },
                            onDismiss = { showSettings = false },
                            onSave = { name, bday ->
                                babyName = name
                                babyBirthDate = bday
                                prefs.edit().putString("baby_name", name).putLong("baby_birthday", bday).apply()
                                showSettings = false
                            }
                        )
                    }

                    Column(modifier = Modifier.padding(innerPadding)) {
                        if (isExpanded && selectedTab == 1) {
                            Row(Modifier.fillMaxSize()) {
                                Box(Modifier.weight(0.4f)) {
                                    DailyLogScreen(onDeleteLatest = { stopBabyTimer() }, snackbarHostState = snackbarHostState)
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

                                            if (category == "FEED") {
                                                startBabyTimer(value, timestamp)
                                                syncLastFeedToWatch(context, timestamp)
                                                TimerWidget().updateAll(context)
                                            }

                                            scope.launch {
                                                snackbarHostState.showSnackbar("${category.lowercase().replaceFirstChar { it.uppercase() }} logged!")
                                            }
                                        }
                                    }
                                )
                                1 -> DailyLogScreen(onDeleteLatest = { stopBabyTimer() }, snackbarHostState = snackbarHostState)
                                2 -> TrendsScreen()
                                3 -> MilestonesScreen(babyBirthDate)
                            }
                        }
                    }
                }
            }
        }
    }

    private fun syncLastFeedToWatch(context: Context, timestamp: Long) {
        val dataClient = Wearable.getDataClient(context)
        val putDataReq = PutDataMapRequest.create("/last_feed").apply {
            dataMap.putLong("timestamp", timestamp)
        }.asPutDataRequest().setUrgent()
        dataClient.putDataItem(putDataReq)
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

@Composable
fun WalkthroughDialog(onDismiss: () -> Unit) {
    var step by remember { mutableIntStateOf(1) }

    AlertDialog(
        onDismissRequest = { },
        confirmButton = {
            Button(onClick = { if (step < 3) step++ else onDismiss() }) {
                Text(if (step < 3) "Next" else "Get Started")
            }
        },
        title = {
            Text(when(step) {
                1 -> "Welcome to Nurture Fox"
                2 -> "Smart Tracking"
                else -> "Home Screen Widget"
            })
        },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Box(modifier = Modifier.size(80.dp).background(MaterialTheme.colorScheme.primaryContainer, shape = CircleShape), contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = when(step) {
                            1 -> Icons.Default.Timer
                            2 -> Icons.Default.Timeline
                            else -> Icons.Default.Settings
                        },
                        contentDescription = null,
                        modifier = Modifier.size(40.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
                Spacer(Modifier.height(16.dp))
                Text(
                    text = when(step) {
                        1 -> "Log your baby's meal to start a timer. It stays synced with your watch and notifications."
                        2 -> "Trends compare today's activity against your 7-day baseline to show you how your baby is doing and growing!"
                        else -> "Customize your Home Screen widgets in settings to log common feed sizes with a single tap."
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center
                )
            }
        }
    )
}

@Composable
fun SettingsDialog(
    currentName: String,
    currentBirthday: Long,
    currentTheme: Int,
    onThemeChange: (Int) -> Unit,
    onShowWalkthrough: () -> Unit,
    onDismiss: () -> Unit,
    onSave: (String, Long) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val prefs = remember { context.getSharedPreferences("BabyClockPrefs", Context.MODE_PRIVATE) }

    var name by remember { mutableStateOf(currentName) }
    var birthday by remember { mutableLongStateOf(currentBirthday) }

    var smallAmount by remember { mutableStateOf(prefs.getString("quick_amount_small", "2") ?: "2") }
    var largeAmount by remember { mutableStateOf(prefs.getString("quick_amount_large", "6") ?: "6") }

    val themeOptions = listOf("System Default", "Light", "Dark")
    var themeExpanded by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Settings") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.verticalScroll(rememberScrollState())
            ) {
                Text("Child Profile", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") }, modifier = Modifier.fillMaxWidth())

                Button(onClick = {
                    val cal = Calendar.getInstance()
                    if (birthday != 0L) cal.timeInMillis = birthday
                    DatePickerDialog(context, { _, y, m, d ->
                        val newCal = Calendar.getInstance()
                        newCal.set(y, m, d)
                        birthday = newCal.timeInMillis
                    }, cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).show()
                }, modifier = Modifier.fillMaxWidth()) {
                    val dateLabel = if (birthday == 0L) "Select Birthday" else SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(Date(birthday))
                    Text(dateLabel)
                }

                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))

                Text("Widget Quick Actions", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = smallAmount,
                        onValueChange = { smallAmount = it },
                        label = { Text("Small oz") },
                        modifier = Modifier.weight(1f),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                    )
                    OutlinedTextField(
                        value = largeAmount,
                        onValueChange = { largeAmount = it },
                        label = { Text("Large oz") },
                        modifier = Modifier.weight(1f),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
                    )
                }

                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))

                Text("Appearance", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                Box(modifier = Modifier.fillMaxWidth()) {
                    OutlinedCard(onClick = { themeExpanded = true }, modifier = Modifier.fillMaxWidth()) {
                        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text("Theme Mode")
                            Text(themeOptions[currentTheme], fontWeight = FontWeight.Bold)
                        }
                    }
                    DropdownMenu(expanded = themeExpanded, onDismissRequest = { themeExpanded = false }) {
                        themeOptions.forEachIndexed { index, label ->
                            DropdownMenuItem(text = { Text(label) }, onClick = {
                                onThemeChange(index)
                                prefs.edit().putInt("theme_pref", index).apply()
                                themeExpanded = false
                            })
                        }
                    }
                }

                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))

                Text("Privacy & Security", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                OutlinedCard(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/olearytd/nurture-fox/blob/main/PRIVACY.md"))
                        context.startActivity(intent)
                    }
                ) {
                    Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column {
                            Text("Privacy Policy", style = MaterialTheme.typography.bodyLarge)
                            Text("View on GitHub", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                        }
                        Icon(Icons.Default.Info, contentDescription = null)
                    }
                }

                TextButton(onClick = onShowWalkthrough, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.Help, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Show App Walkthrough")
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                prefs.edit().putString("quick_amount_small", smallAmount).putString("quick_amount_large", largeAmount).apply()
                scope.launch { ActionWidget().updateAll(context) }
                onSave(name, birthday)
            }) { Text("Save All") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
fun MilestonesScreen(babyBirthday: Long) {
    val milestones by BabyApplication.database.babyDao().getAllMilestones().collectAsState(initial = emptyList())
    val scope = rememberCoroutineScope()

    val milestoneOptions = listOf(
        "First Smile", "First Laugh", "Rolling Over", "Sitting Up",
        "First Solid Food", "Crawling", "First Word", "First Steps",
        "Waving Bye-Bye", "Pulling to Stand", "First Tooth", "Walking"
    )

    Column(modifier = Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState())) {
        Text("Developmental Milestones", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))

        if (babyBirthday == 0L) {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                Text(
                    "Set birthday in Settings (gear icon) to calculate age!",
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer
                )
            }
            Spacer(Modifier.height(16.dp))
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("What happened recently?", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                milestoneOptions.chunked(2).forEach { pair ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        pair.forEach { mName ->
                            OutlinedButton(
                                onClick = {
                                    val now = System.currentTimeMillis()
                                    val age = calculateAge(babyBirthday, now)
                                    scope.launch {
                                        BabyApplication.database.babyDao().insertMilestone(
                                            Milestone(name = mName, timestamp = now, ageAtOccurrence = age)
                                        )
                                    }
                                },
                                modifier = Modifier.weight(1f).padding(vertical = 4.dp)
                            ) { Text(mName) }
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(24.dp))
        Text("Memory Book", style = MaterialTheme.typography.titleLarge)

        if (milestones.isEmpty()) {
            Text("No milestones logged yet. Tap a milestone above to save a memory!", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 8.dp))
        }

        milestones.forEach { milestone ->
            ListItem(
                headlineContent = { Text(milestone.name, fontWeight = FontWeight.Bold) },
                supportingContent = { Text("Accomplished at: ${milestone.ageAtOccurrence}") },
                leadingContent = { Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFFFD700)) },
                trailingContent = {
                    IconButton(onClick = { scope.launch { BabyApplication.database.babyDao().deleteMilestone(milestone) } }) {
                        Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
                    }
                }
            )
            HorizontalDivider()
        }
    }
}

fun calculateAge(birthday: Long, milestoneDate: Long): String {
    if (birthday == 0L) return "Unknown"
    val bDay = Calendar.getInstance().apply { timeInMillis = birthday }
    val mDay = Calendar.getInstance().apply { timeInMillis = milestoneDate }

    var years = mDay.get(Calendar.YEAR) - bDay.get(Calendar.YEAR)
    var months = mDay.get(Calendar.MONTH) - bDay.get(Calendar.MONTH)
    var days = mDay.get(Calendar.DAY_OF_MONTH) - bDay.get(Calendar.DAY_OF_MONTH)

    if (days < 0) {
        months--
        days += mDay.getActualMaximum(Calendar.DAY_OF_MONTH)
    }
    if (months < 0) {
        years--
        months += 12
    }

    return buildString {
        if (years > 0) append("$years y, ")
        if (months > 0 || years > 0) append("$months m, ")
        append("$days d")
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BabyClockScreen(onLogEvent: (String, String, String, Long) -> Unit) {
    var amountText by remember { mutableStateOf("") }
    var isOz by remember { mutableStateOf(true) }
    var showDiaperSheet by remember { mutableStateOf(false) }
    val context = LocalContext.current

    // Combined Date and Time state
    var customTimestamp by remember { mutableStateOf<Long?>(null) }
    val displayTime = customTimestamp?.let {
        SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(Date(it))
    } ?: "Now"

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = "Nurture Fox", style = MaterialTheme.typography.headlineLarge, color = MaterialTheme.colorScheme.onBackground)
        Spacer(modifier = Modifier.height(24.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(" Logging for: ", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onBackground)
            TextButton(onClick = {
                val cal = Calendar.getInstance()
                if (customTimestamp != null) cal.timeInMillis = customTimestamp!!

                // Chain: Date Picker then Time Picker
                DatePickerDialog(context, { _, y, m, d ->
                    cal.set(y, m, d)
                    TimePickerDialog(context, { _, h, min ->
                        cal.set(Calendar.HOUR_OF_DAY, h)
                        cal.set(Calendar.MINUTE, min)
                        customTimestamp = cal.timeInMillis
                    }, cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE), false).show()
                }, cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).show()
            }) {
                Text(displayTime, fontWeight = FontWeight.Bold)
            }
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

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun DailyLogScreen(onDeleteLatest: () -> Unit, snackbarHostState: SnackbarHostState) {
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

    val historyLimit = todayStart - (13 * 24 * 60 * 60 * 1000L)
    val recentEvents = events.filter { it.timestamp >= historyLimit }

    val listState = rememberLazyListState()

    if (editingEvent != null) {
        EditEventDialog(
            event = editingEvent!!,
            onDismiss = { editingEvent = null },
            onConfirm = { newAmount, newUnit, newTimestamp ->
                scope.launch {
                    BabyApplication.database.babyDao().updateEvent(editingEvent!!.copy(amountMl = newAmount, subtype = newUnit, timestamp = newTimestamp))
                    editingEvent = null
                    snackbarHostState.showSnackbar("Updated to $newAmount $newUnit")
                }
            },
            onRestartTimer = { timestamp, amount ->
                val intent = Intent(context, TimerService::class.java).apply {
                    putExtra("START_TIME", timestamp)
                    putExtra("FEED_AMOUNT", amount)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                editingEvent = null
                scope.launch { snackbarHostState.showSnackbar("Timer restarted!") }
            }
        )
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

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(text = "History (Last 14 Days)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)

            IconButton(onClick = {
                val cal = Calendar.getInstance()
                DatePickerDialog(context, { _, y, m, d ->
                    val selected = Calendar.getInstance().apply { set(y, m, d) }
                    val targetDate = SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(selected.time)
                    val grouped = recentEvents.groupBy { SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(Date(it.timestamp)) }

                    val index = grouped.keys.toList().indexOf(targetDate)
                    if (index != -1) {
                        scope.launch { listState.animateScrollToItem(index * 2) }
                    }
                }, cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).show()
            }) {
                Icon(Icons.Default.DateRange, contentDescription = "Jump to date", tint = MaterialTheme.colorScheme.primary)
            }
        }

        LazyColumn(modifier = Modifier.fillMaxSize(), state = listState) {
            val groupedEvents = recentEvents.groupBy { SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(Date(it.timestamp)) }
            groupedEvents.forEach { (date, eventsInDay) ->
                stickyHeader {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = MaterialTheme.colorScheme.background
                    ) {
                        Column {
                            Text(text = date, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(vertical = 8.dp))
                            HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)
                        }
                    }
                }

                items(items = eventsInDay, key = { "${it.id}_${it.type}" }) { event ->
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
fun EditEventDialog(
    event: BabyEvent,
    onDismiss: () -> Unit,
    onConfirm: (Float, String, Long) -> Unit,
    onRestartTimer: (Long, String) -> Unit
) {
    val context = LocalContext.current
    var amountText by remember { mutableStateOf(event.amountMl.toString()) }
    var selectedUnit by remember { mutableStateOf(event.subtype) }

    val calendar = remember { Calendar.getInstance().apply { timeInMillis = event.timestamp } }
    var selectedTimeText by remember { mutableStateOf(SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(calendar.time)) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (event.type == "FEED") "Edit Feed" else "Edit Diaper") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (event.type == "FEED") {
                    OutlinedTextField(
                        value = amountText,
                        onValueChange = { newText ->
                            amountText = newText
                            val value = newText.toFloatOrNull() ?: 0f
                            if (value > 0) {
                                selectedUnit = if (value >= 9.5f) "ml" else "oz"
                            }
                        },
                        label = { Text("Amount") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        modifier = Modifier.fillMaxWidth(),
                        trailingIcon = {
                            Button(
                                onClick = { selectedUnit = if (selectedUnit == "oz") "ml" else "oz" },
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                                modifier = Modifier.padding(end = 4.dp).height(32.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.secondaryContainer,
                                    contentColor = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                            ) {
                                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(Modifier.width(4.dp))
                                Text(selectedUnit, style = MaterialTheme.typography.labelMedium)
                            }
                        }
                    )

                    Button(
                        onClick = { onRestartTimer(event.timestamp, amountText) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
                    ) {
                        Icon(Icons.Default.Refresh, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text("Restart Notification Timer")
                    }
                }

                Button(onClick = {
                    TimePickerDialog(context, { _, h, m ->
                        calendar.set(Calendar.HOUR_OF_DAY, h); calendar.set(Calendar.MINUTE, m);
                        selectedTimeText = SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(calendar.time)
                    }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), false).show()
                }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.Edit, null, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("Time: $selectedTimeText")
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                onConfirm(amountText.toFloatOrNull() ?: event.amountMl, selectedUnit, calendar.timeInMillis)
            }) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
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
    calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0); calendar.set(Calendar.SECOND, 0); calendar.set(Calendar.MILLISECOND, 0)
    val startOfToday = calendar.timeInMillis
    val timeElapsedToday = now - startOfToday
    val todayEvents = events.filter { it.timestamp in startOfToday..now }
    val todayVol = todayEvents.filter { it.type == "FEED" }.sumOf { if(it.subtype == "oz") it.amountMl.toDouble() else it.amountMl / 30.0 }
    val todayDiapers = todayEvents.count { it.type == "DIAPER" }

    var totalBaselineVol = 0.0
    var totalBaselineDiapers = 0
    var activeDaysCount = 0

    for (i in 1..7) {
        val dayStart = startOfToday - (i * 24 * 60 * 60 * 1000L)
        val dayEnd = dayStart + timeElapsedToday
        val dayEvents = events.filter { it.timestamp in dayStart..dayEnd }
        val fullDayEvents = events.filter { it.timestamp in dayStart..(dayStart + 24 * 60 * 60 * 1000L) }
        if (fullDayEvents.isNotEmpty()) {
            activeDaysCount++
            totalBaselineVol += dayEvents.filter { it.type == "FEED" }.sumOf { if(it.subtype == "oz") it.amountMl.toDouble() else it.amountMl / 30.0 }
            totalBaselineDiapers += dayEvents.count { it.type == "DIAPER" }
        }
    }

    val avgBaselineVol = if (activeDaysCount > 0) totalBaselineVol / activeDaysCount else 0.0
    val avgBaselineDiapers = if (activeDaysCount > 0) totalBaselineDiapers.toDouble() / activeDaysCount else 0.0

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

        StatCategoryCard("7-Day Baseline Comparison") {
            Text("Today vs. Weekly Avg so far (up to ${SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(now))})", style = MaterialTheme.typography.labelSmall)
            Spacer(Modifier.height(8.dp))
            StatRow("Vol Today", "%.1f oz".format(todayVol))
            StatRow("7-Day Avg", "%.1f oz".format(avgBaselineVol))
            val volDiff = todayVol - avgBaselineVol
            val volColor = if (volDiff >= 0) Color(0xFF4CAF50) else Color(0xFFF44336)
            Text(text = "${if(volDiff >= 0) "+" else ""}${"%.1f".format(volDiff)} oz vs. baseline", color = volColor, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
            if (activeDaysCount < 7) {
                Text("Note: Baseline based on $activeDaysCount days of data.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary, modifier = Modifier.padding(top = 4.dp))
            }
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            StatRow("Diapers Today", "$todayDiapers")
            StatRow("7-Day Avg", "%.1f".format(avgBaselineDiapers))
            val diaperDiff = todayDiapers - avgBaselineDiapers
            Text(text = "${if(diaperDiff >= 0) "+" else ""}${"%.1f".format(diaperDiff)} diapers vs. baseline", style = MaterialTheme.typography.labelSmall, color = if (diaperDiff >= 0) Color(0xFF4CAF50) else Color(0xFFF44336))
        }

        Spacer(modifier = Modifier.height(16.dp))
        ChartCard("Volume (oz) - Last 24h", modelProducer24h)
        Spacer(modifier = Modifier.height(16.dp))
        ChartCard("Daily Volume (oz) - Last 7 Days", modelProducer7d)

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