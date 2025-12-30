package com.toleary.babyclock

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update

@Dao
interface BabyDao {
    @Insert
    suspend fun insertEvent(event: BabyEvent)

    @Query("SELECT * FROM events_table ORDER BY timestamp DESC")
    fun getAllEvents(): kotlinx.coroutines.flow.Flow<List<BabyEvent>>

    @Delete
    suspend fun deleteEvent(event: BabyEvent)

    @Update
    suspend fun updateEvent(event: BabyEvent)
}