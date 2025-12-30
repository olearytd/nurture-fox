package com.toleary.babyclock

import android.app.Application
import androidx.room.Room

class BabyApplication : Application() {
    // We make the database accessible globally
    companion object {
        lateinit var database: AppDatabase
    }

    // Inside BabyApplication.kt
    override fun onCreate() {
        super.onCreate()
        database = Room.databaseBuilder(
            applicationContext,
            AppDatabase::class.java,
            "baby_clock_db"
        )
            .fallbackToDestructiveMigration() // <--- ADD THIS LINE
            .build()
    }
}