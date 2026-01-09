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

    @Query("SELECT * FROM events_table WHERE type = 'FEED' ORDER BY timestamp DESC LIMIT 1")
    suspend fun getLatestFeedSync(): BabyEvent?

    @Query("SELECT * FROM milestones ORDER BY timestamp DESC")
    fun getAllMilestones(): kotlinx.coroutines.flow.Flow<List<Milestone>>

    @Insert
    suspend fun insertMilestone(milestone: Milestone)

    @Delete
    suspend fun deleteMilestone(milestone: Milestone)
}