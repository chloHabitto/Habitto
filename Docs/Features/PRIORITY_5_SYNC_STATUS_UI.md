# 🎨 Priority 5: Sync Status UI Indicators

**Status**: 📋 **BACKLOG** (UI Enhancement)  
**Priority**: Low (Polish feature)  
**Type**: User-facing UI enhancement

---

## Overview

This is a **UI enhancement task** for improving user visibility into sync status. The core sync functionality is already operational; this adds user-facing indicators and controls.

**Note**: This was originally Priority 5 in the Data Architecture & Migration Plan, but has been moved to a separate UI enhancement task since it's not required for core architecture functionality.

---

## Features to Implement

### 1. Sync Status Badge on More Tab

**Location**: `Views/Tabs/MoreTabView.swift`

**Implementation**:
- Show badge with unsynced count (e.g., "3 unsynced")
- Badge appears when `SyncEngine.unsyncedCount > 0`
- Clicking badge shows sync status details
- Badge clears when sync completes

**UI Design**:
```
More Tab
┌─────────────────┐
│ ⚙️ Settings     │
│ 📊 Statistics   │
│ 🔄 Sync Status  │ ← Badge: "3 unsynced"
│ 🆘 Help         │
└─────────────────┘
```

---

### 2. Pull-to-Refresh on Home Screen

**Location**: `Views/Tabs/HomeTabView.swift`

**Implementation**:
- Add `.refreshable` modifier to home screen list
- Trigger manual sync when user pulls down
- Show refresh indicator during sync
- Display sync success/error toast after completion

**Code Example**:
```swift
List {
    // ... habit items
}
.refreshable {
    await habitRepository.triggerManualSync()
}
```

---

### 3. "Last Synced: X ago" Display

**Location**: Settings or Home screen header

**Implementation**:
- Display last successful sync timestamp
- Format: "Last synced: 5 minutes ago"
- Update automatically as time passes
- Show "Never synced" if no sync has occurred

**UI Design**:
```
┌─────────────────────────────┐
│ Habitto                     │
│ Last synced: 5 minutes ago  │ ← Status indicator
├─────────────────────────────┤
│ [Habit List]                │
└─────────────────────────────┘
```

---

### 4. Sync Icon Animation

**Location**: Settings or Home screen header

**Implementation**:
- Animated sync icon when sync is in progress
- Static icon when sync is idle
- Error icon when sync fails
- Success checkmark briefly after successful sync

**Animation States**:
- 🔄 Spinning (sync in progress)
- ✅ Checkmark (sync completed)
- ❌ Error (sync failed)
- ⏸️ Idle (no sync activity)

---

### 5. Enhanced Sync Status Toast

**Current**: Basic toast notifications exist (`SyncSuccessToast`, `SyncErrorToast`)

**Enhancements**:
- Show sync progress (e.g., "Syncing 3 items...")
- Display itemized sync results
- Add "View Details" button to error toasts
- Show sync duration/performance metrics

---

## Implementation Plan

### Phase 1: Sync Status Tracking

1. Add `SyncStatus` model to track:
   - Last sync timestamp
   - Unsynced item count
   - Current sync state (idle, syncing, error)
   - Sync progress percentage

2. Expose sync status via `SyncEngine`:
   ```swift
   actor SyncEngine {
       var syncStatus: SyncStatus { get }
       var unsyncedCount: Int { get }
       var lastSyncTimestamp: Date? { get }
   }
   ```

### Phase 2: UI Components

1. **Sync Status Badge**
   - Create `SyncStatusBadgeView.swift`
   - Add to `MoreTabView`
   - Update based on `SyncEngine.unsyncedCount`

2. **Pull-to-Refresh**
   - Add `.refreshable` to `HomeTabView`
   - Call `SyncEngine.triggerManualSync()`
   - Show loading indicator

3. **Last Synced Display**
   - Create `LastSyncedView.swift`
   - Add to Home screen header or Settings
   - Use `RelativeDateTimeFormatter` for formatting

4. **Sync Icon Animation**
   - Create `SyncIconView.swift`
   - Animate based on sync state
   - Use `Lottie` or native SwiftUI animations

### Phase 3: Enhanced Toasts

1. Add progress indicators to sync toasts
2. Show itemized sync results
3. Add "View Details" navigation

---

## Design Considerations

### Performance
- Sync status updates should be lightweight
- Avoid excessive UI updates during sync
- Cache sync status and update periodically

### User Experience
- Don't overwhelm users with sync details
- Show errors prominently but not intrusively
- Make sync status discoverable but not distracting

### Accessibility
- Ensure sync status is accessible via VoiceOver
- Provide clear error messages
- Support dynamic type for all text

---

## Testing Checklist

- [ ] Sync badge appears/disappears correctly
- [ ] Pull-to-refresh triggers sync
- [ ] Last synced timestamp updates correctly
- [ ] Sync icon animates during sync
- [ ] Toast notifications show correct information
- [ ] All UI elements accessible via VoiceOver
- [ ] Performance acceptable (no UI lag during sync)

---

## Related Files

- `Core/Data/Sync/SyncEngine.swift` - Sync engine implementation
- `Views/Components/SyncSuccessToast.swift` - Success toast
- `Views/Components/SyncErrorToast.swift` - Error toast
- `Views/Tabs/HomeTabView.swift` - Home screen
- `Views/Tabs/MoreTabView.swift` - More tab

---

## Priority

**Status**: Low priority (UI polish)

**Rationale**:
- Core sync functionality is working
- Users can verify sync via debug UI if needed
- This is primarily a UX enhancement
- Can be implemented incrementally

**Recommendation**: Implement when time permits, or prioritize based on user feedback.

---

**Last Updated**: Migration Plan Completion  
**Next Steps**: Move to UI enhancement backlog or implement incrementally

