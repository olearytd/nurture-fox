package com.toleary.babyclock

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

class TimerService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Get the time the button was pressed
        val startTime = intent?.getLongExtra("START_TIME", System.currentTimeMillis())
            ?: System.currentTimeMillis()

        // Makes the notification clickable to return to the app
        val pendingIntent: PendingIntent = Intent(this, MainActivity::class.java).let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }

        val notification: Notification = NotificationCompat.Builder(this, "BABY_CHANNEL")
            .setContentTitle("Last Fed")
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setUsesChronometer(true) // This makes the timer count up live!
            .setWhen(startTime)
            .build()

        startForeground(1, notification)

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}