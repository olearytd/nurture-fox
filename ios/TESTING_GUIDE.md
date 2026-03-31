# Testing Guide - Core Data Migration

## 🧪 Pre-Testing Setup

### Requirements
- Physical iOS device (CloudKit doesn't work in simulator)
- iCloud account signed in
- Latest Xcode build

### Clean Slate (Optional)
If you want to test migration from scratch:

1. **Backup your data first!** (Export CSV from Settings)
2. Delete app from device
3. Clean build folder in Xcode (Cmd+Shift+K)
4. Build and install fresh

---

## 📝 Test Plan

### Phase 1: iOS App Basic Functionality ✅

**Already Tested:**
- [x] Build succeeds
- [x] App runs in simulator
- [x] Can view existing data
- [x] Can add new feed events
- [x] Can add new diaper events

**Still Need to Test:**
- [ ] Edit existing events
- [ ] Delete events
- [ ] Export to CSV
- [ ] Import from CSV
- [ ] Trends view displays charts correctly
- [ ] Daily log grouping works

### Phase 2: Watch App Basic Functionality

**Test Steps:**

1. **Build and Install Watch App**
   ```
   1. Select "NurtureFoxWatch Watch App" scheme in Xcode
   2. Select your paired Watch as target
   3. Build and Run (Cmd+R)
   ```

2. **Verify Data Sync**
   - [ ] Open Watch app
   - [ ] Check "Last Feed" section
   - [ ] Does it show the same last feed as iOS app?

3. **Test Quick Feed Buttons**
   - [ ] Tap "3oz" button
   - [ ] Confirm you feel haptic feedback
   - [ ] Switch to iOS app - does new feed appear?
   - [ ] Tap "4oz" button on Watch
   - [ ] Verify on iOS app

4. **Test Diaper Logging**
   - [ ] Tap "Diaper..." button
   - [ ] Select "Pee"
   - [ ] Confirm haptic feedback
   - [ ] Check iOS app - does diaper event appear?
   - [ ] Try "Poop" and "Both" options

### Phase 3: Widget Testing

**iPhone Home Screen Widget:**

1. **Add Widget**
   ```
   1. Long press on home screen
   2. Tap + button
   3. Search for "Nurture Fox"
   4. Add small widget
   ```

2. **Verify Display**
   - [ ] Widget shows "Last Fed"
   - [ ] Shows correct time (relative format)
   - [ ] Shows "at HH:MM" with actual time

3. **Test Updates**
   - [ ] Add new feed in app
   - [ ] Wait ~30 seconds
   - [ ] Widget should update (or force touch and "Refresh Widget")

**Watch Face Complication:**

1. **Add to Watch Face**
   ```
   1. Long press on watch face
   2. Tap "Edit"
   3. Select a complication slot
   4. Find "Nurture Fox"
   5. Select "Circular" or "Inline" style
   ```

2. **Verify Display**
   - [ ] Shows bottle icon (🍼)
   - [ ] Shows relative time

### Phase 4: CloudKit Sync Testing

**This is the big one!**

1. **Two-Device Setup**
   - Device A: Your primary iPhone
   - Device B: Another iPhone/iPad with same iCloud account

2. **Initial Sync Test**
   ```
   Device A:
   1. Add a feed event with distinctive time (e.g., 5.5oz)
   2. Wait 10-30 seconds
   
   Device B:
   1. Open app
   2. Pull to refresh (if applicable)
   3. Does the 5.5oz feed appear?
   ```

3. **Bi-directional Sync**
   ```
   Device B:
   1. Add a diaper event
   2. Wait 10-30 seconds
   
   Device A:
   1. Check if diaper event appears
   ```

4. **Watch to iPhone Sync**
   ```
   Watch:
   1. Add 3oz feed
   
   iPhone:
   1. Wait 10-30 seconds
   2. Does 3oz feed appear?
   ```

### Phase 5: Migration Testing

**If You Have Old SwiftData:**

1. **Check Migration Logs**
   ```
   1. Open Console app on Mac
   2. Connect iPhone via cable
   3. Filter for "nurture-fox"
   4. Look for:
      - "🔄 Starting migration..."
      - "📊 Found X events..."
      - "✅ Migration completed successfully!"
   ```

2. **Verify Data Integrity**
   - [ ] Count events before migration (if possible)
   - [ ] Count events after migration
   - [ ] Numbers match?
   - [ ] No duplicate events?

3. **Watch Migration**
   ```
   1. Install updated Watch app
   2. Check Watch console logs for:
      - "🔄 Starting Watch migration..."
      - "📊 Watch found X events..."
      - "✅ Successfully migrated X items..."
      OR
      - "ℹ️ All Watch data already exists..."
   ```

### Phase 6: Live Activity Testing

**Test LogDiaperIntent:**

1. **Start a Live Activity**
   ```
   1. Add a feed in iOS app
   2. Tap "Restart Live Activity" if visible
   3. Lock the phone
   4. Verify Live Activity appears on lock screen
   ```

2. **Test Intent Button** (if you have one)
   - [ ] Tap diaper button on Live Activity
   - [ ] Unlock phone
   - [ ] Check if diaper was logged

---

## 🐛 Known Issues to Watch For

### CloudKit Sync Delays
- **Expected:** 5-30 seconds delay
- **If longer:** Check iCloud account status in Settings
- **Fix:** Toggle iCloud Drive off/on

### Migration Issues
- **Duplicate Events:** Should NOT happen with UUID deduplication
- **Missing Events:** Check console logs for migration errors
- **Performance:** Large datasets (>1000 events) may take longer

### Widget Not Updating
- **Fix 1:** Force touch widget → "Refresh Widget"
- **Fix 2:** Remove and re-add widget
- **Fix 3:** Rebuild widget extension

### Watch App Not Showing Data
- **Check 1:** Is Watch paired and unlocked?
- **Check 2:** Is Watch app actually installed? (Check Watch app on iPhone)
- **Check 3:** Check Watch console logs for errors

---

## 📊 Success Criteria

✅ **Complete Success:**
- All events sync between iOS, Watch, and Widgets
- No duplicate events
- CloudKit sync works within 30 seconds
- Migration preserves all data
- No crashes or data loss

⚠️ **Partial Success:**
- Everything works but sync is slow (>1 minute)
- Some console warnings but no data loss
- Widget updates require manual refresh

❌ **Failure:**
- Duplicate events appear
- Data loss after migration
- CloudKit sync doesn't work at all
- Crashes on launch

---

## 🆘 Troubleshooting

### If Something Goes Wrong

1. **Check Console Logs**
   - Connect device to Mac
   - Open Console.app
   - Filter for "nurture-fox"
   - Look for ERROR or ❌ messages

2. **Check CloudKit Dashboard**
   - https://icloud.developer.apple.com/
   - Sign in with Apple ID
   - Select "iCloud.com.toleary.nurturefox"
   - Check for sync errors

3. **Reset Migration** (last resort)
   ```
   1. Backup data (Export CSV)
   2. In app delegate, add:
      UserDefaults.standard.set(false, forKey: "hasCompletedSwiftDataToCoreDataMigration")
      UserDefaults.standard.set(false, forKey: "hasCompletedWatchSwiftDataToCoreDataMigration")
   3. Delete app
   4. Clean build
   5. Reinstall
   6. Migration will run again
   ```

4. **Nuclear Option** (complete reset)
   ```
   1. Export CSV backup
   2. Delete app from all devices
   3. Delete from CloudKit Dashboard (Development/Production data)
   4. Clean Xcode build
   5. Reinstall fresh
   6. Import CSV
   ```

---

## 📸 Evidence Collection

As you test, capture:
- Screenshots of successful sync
- Console logs showing migration
- CloudKit Dashboard showing records
- Widget displaying correct data

This helps verify everything works! 🎉

