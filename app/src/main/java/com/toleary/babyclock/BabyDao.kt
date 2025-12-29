package com.toleary.babyclock

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface BabyDao {
    @Insert
    suspend fun insertEvent(event: BabyEvent)

    @Query("SELECT * FROM events_table ORDER BY timestamp DESC LIMIT 1")
    suspend fun getLastEvent(): BabyEvent?

    @Query("SELECT * FROM events_table WHERE type = 'FEED' ORDER BY timestamp DESC LIMIT 1")
    suspend fun getLastFeeding(): BabyEvent?
}