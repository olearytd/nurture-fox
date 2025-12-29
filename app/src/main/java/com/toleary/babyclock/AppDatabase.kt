package com.toleary.babyclock

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [BabyEvent::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun babyDao(): BabyDao
}