package com.toleary.babyclock

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "events_table")
data class BabyEvent(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val type: String, // "FEED" or "DIAPER"
    val subtype: String, // "Pee", "Poop", "Both", or "Bottle"
    val amountMl: Float, // We will convert Oz to Ml before saving
    val timestamp: Long = System.currentTimeMillis()
)