package com.toleary.babyclock

import androidx.glance.appwidget.GlanceAppWidgetReceiver

class TimerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = TimerWidget()
}

class ActionWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = ActionWidget()
}