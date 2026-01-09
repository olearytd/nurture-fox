package com.toleary.babyclock

import android.content.Context
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class WidgetWorker(private val context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): androidx.work.ListenableWorker.Result {
        TimerWidget().updateAll(context)
        return androidx.work.ListenableWorker.Result.success()
    }
}