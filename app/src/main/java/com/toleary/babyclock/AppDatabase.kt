package com.toleary.babyclock

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [BabyEvent::class, Milestone::class], version = 4, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun babyDao(): BabyDao
}