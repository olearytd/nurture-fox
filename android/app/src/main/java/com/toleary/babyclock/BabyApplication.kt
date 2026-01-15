package com.toleary.babyclock

import android.app.Application
import android.content.Context
import androidx.room.Room
import androidx.room.RoomDatabase
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory

class BabyApplication : Application() {
    companion object {
        lateinit var database: AppDatabase
    }

    override fun onCreate() {
        super.onCreate()
        System.loadLibrary("sqlcipher")

        // Check if we've already performed the v2.0 upgrade purge
        val prefs = getSharedPreferences("BabyClockPrefs", Context.MODE_PRIVATE)
        val hasPurgedForEncryption = prefs.getBoolean("v2_migration_complete", false)

        if (!hasPurgedForEncryption) {
            // Force delete the old database files to prevent encryption crashes
            applicationContext.deleteDatabase("baby_clock_db")

            // Mark as complete so we don't wipe data every time the app opens!
            prefs.edit().putBoolean("v2_migration_complete", true).apply()
        }

        // Now proceed with building the encrypted database
        database = Room.databaseBuilder(
            applicationContext,
            AppDatabase::class.java,
            "baby_clock_db"
        )
            .openHelperFactory(SupportOpenHelperFactory(EncryptionManager.getDatabasePassphrase(this)))
            .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
            .fallbackToDestructiveMigration()
            .build()
    }
}