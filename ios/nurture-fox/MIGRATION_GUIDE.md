# Migration Guide: Fixing CloudKit Duplicate Records

## Problem Summary
Records were duplicating during iCloud sync because the `BabyEvent` and `Milestone` models were regenerating UUIDs during CloudKit sync, causing SwiftData to treat synced records as new records.

## Solution Implemented
We've implemented a SwiftData migration that:
1. Adds `@Attribute(.unique)` to the `id` field
2. Automatically deduplicates existing records
3. Prevents future duplicates

## What Changed

### Files Modified
- `BabyEvent.swift` - Added unique constraint to models
- `DataMigration.swift` - NEW: Migration logic with deduplication
- `nurture_foxApp.swift` - Updated to use migration plan
- `NurtureFoxWatchApp.swift` - Updated Watch app
- `NurtureFoxWidgets.swift` - Updated Widget extension
- `LogDiaperIntent.swift` - Updated Intent handler

### Schema Changes
**Before (V1):**
```swift
@Model
final class BabyEvent {
    var id: UUID = UUID()  // No unique constraint
    ...
}
```

**After (V2):**
```swift
@Model
final class BabyEvent {
    @Attribute(.unique) var id: UUID  // Unique constraint added
    ...
}
```

## Migration Process

### What Happens Automatically
When you run the updated app:

1. **Migration Detection**: SwiftData detects the schema change
2. **Deduplication**: The migration removes duplicate records based on UUID
3. **Schema Update**: Applies the unique constraint
4. **Sync**: CloudKit syncs the cleaned data across devices

### Testing the Migration

#### Option 1: Test on One Device First (Recommended)
1. **Backup your data** using the app's export feature
2. Update and run the app on ONE device first
3. Check the Xcode console for migration messages:
   ```
   Migration: Removed X duplicate BabyEvents
   Migration: Removed X duplicate Milestones
   ```
4. Verify your data looks correct
5. Update other devices

#### Option 2: Clean Install (Nuclear Option)
If you want a completely fresh start:
1. Export your data from Settings
2. Delete the app from ALL devices
3. Install the updated version
4. Import your data back

### Expected Console Output
When the migration runs, you'll see:
```
Migration: Removed 15 duplicate BabyEvents
Migration: Removed 3 duplicate Milestones
```

The numbers will vary based on how many duplicates you have.

## Verification Steps

After migration:
1. ✅ Check that your events appear once (not duplicated)
2. ✅ Add a new event on Device A
3. ✅ Wait for sync (check Settings > Cloud Sync status)
4. ✅ Open Device B - event should appear ONCE
5. ✅ Repeat in reverse - add on Device B, check Device A

## Troubleshooting

### "Migration failed" error
- Make sure all devices are updated to the new version
- Try deleting and reinstalling if the error persists

### Still seeing duplicates after migration
- The migration only removes duplicates with the same UUID
- If you have records with different UUIDs but same data, you may need to manually delete them
- Future syncs will NOT create duplicates

### Data loss concerns
- The migration only deletes records with IDENTICAL UUIDs
- Your unique data is preserved
- Always export a backup before updating

## CloudKit Sync Notes

### How It Works Now
1. Device A creates a record with UUID `abc-123`
2. CloudKit syncs to Device B
3. Device B receives the record and preserves UUID `abc-123`
4. SwiftData recognizes it's the same record (unique constraint)
5. ✅ No duplicate created!

### Before This Fix
1. Device A creates a record with UUID `abc-123`
2. CloudKit syncs to Device B
3. Device B receives data and generates NEW UUID `xyz-789`
4. SwiftData sees different UUID = different record
5. ❌ Duplicate created!

## Support

If you encounter issues:
1. Check Xcode console for error messages
2. Export your data before making changes
3. Test on one device before updating all devices
4. The migration is automatic and should "just work"

## Technical Details

The migration uses SwiftData's `SchemaMigrationPlan`:
- **V1 Schema**: Original models without unique constraint
- **V2 Schema**: Updated models with `@Attribute(.unique)`
- **Migration Stage**: Custom migration that deduplicates before applying constraints

This ensures a smooth transition without data loss.

