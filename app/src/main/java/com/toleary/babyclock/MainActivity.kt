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
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.toleary.babyclock.ui.theme.BabyClockTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // This pops up the "Allow Notifications?" box on first run
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
        }

        // Setup the "channel" so Android allows the notification
        createNotificationChannel()

        setContent {
            BabyClockTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    BabyClockScreen(
                        modifier = Modifier.padding(innerPadding),
                        onLogFeed = { amount ->
                            startBabyTimer()
                            // Later we will add: saveToDatabase(amount)
                        }
                    )
                }
            }
        }
    }

    private fun startBabyTimer() {
        val intent = Intent(this, TimerService::class.java).apply {
            // Tells the timer to start "counting up" from exactly right now
            putExtra("START_TIME", System.currentTimeMillis())
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
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel("BABY_CHANNEL", name, importance)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}

@Composable
fun BabyClockScreen(modifier: Modifier = Modifier, onLogFeed: (String) -> Unit) {
    var amountText by remember { mutableStateOf<String>("") }
    var isOz by remember { mutableStateOf<Boolean>(true) }

    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = "Baby Clock", style = MaterialTheme.typography.headlineLarge)

        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = amountText,
            onValueChange = { amountText = it },
            label = { Text(if (isOz) "Amount (oz)" else "Amount (ml)") },
            modifier = Modifier.width(240.dp)
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(vertical = 8.dp)
        ) {
            Text("mL")
            Switch(
                checked = isOz,
                onCheckedChange = { isOz = it },
                modifier = Modifier.padding(horizontal = 8.dp)
            )
            Text("Oz")
        }

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                onLogFeed(amountText)
                amountText = "" // Clear input after logging
            },
            modifier = Modifier.fillMaxWidth(0.7f)
        ) {
            Text("Log Feed & Start Timer")
        }

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = { /* Diaper logic coming soon */ },
            modifier = Modifier.fillMaxWidth(0.7f),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
        ) {
            Text("Log Diaper")
        }
    }
}