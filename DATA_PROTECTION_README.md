# Data Protection Quick Reference

## 🛡️ What's Protected

- ✅ **SwiftData Migration System** - Automatic schema migrations prevent data loss
- ✅ **Automatic Backups** - Every 24 hours, keeps last 10 backups
- ✅ **Corruption Detection** - Auto-detects and recovers from database issues
- ✅ **UserDefaults Fallback** - Emergency backup if database fails
- ✅ **Error Handling** - Try-catch around all save operations
- ✅ **Integrity Checks** - XP and completion record validation on launch

## 📝 What to Remember

### When Making Schema Changes:

1. **Adding optional field?** → Create V2 schema + lightweight migration
2. **Adding new model?** → Create V2 schema + lightweight migration  
3. **Removing/changing field?** → Create V2 schema + custom migration
4. **Always test** on existing database before release

### Before Releasing:

- [ ] Test migration on development database
- [ ] Test fresh install (no migration)
- [ ] Test upgrade path (with migration)
- [ ] Verify data integrity after migration
- [ ] Check logs for migration errors

## 📚 Where to Find Details

- **Schema Changes:** `SCHEMA_CHANGE_GUIDELINES.md`
- **Data Safety:** `DATA_SAFETY_GUIDE.md`
- **Migration System:** `MIGRATION_SYSTEM_SUMMARY.md`
- **Rollback Plan:** `MIGRATION_ROLLBACK_PLAN.md`
- **Technical Details:** `Core/Data/SwiftData/Migrations/MIGRATION_GUIDE.md`

## 🚨 Emergency Procedures

### If Migration Fails:

1. **Check logs** - Look for migration errors in Xcode console
2. **Check backups** - Verify backups exist (Settings → Backup & Restore)
3. **Restore from backup** - Use latest backup to restore data
4. **Rollback app version** - See `MIGRATION_ROLLBACK_PLAN.md`
5. **Contact support** - If issue persists

### If Data is Missing:

1. **Check UserDefaults fallback** - App should auto-recover
2. **Check backups** - Restore from backup if available
3. **Check logs** - Look for corruption/recovery messages
4. **Verify migration ran** - Check migration records in database

## ⚡ Quick Commands

```bash
# Build and check for errors
xcodebuild -scheme Habitto -sdk iphonesimulator build

# Run migration tests
# (Use SchemaMigrationTestRunner from app)

# Check database location
# ~/Library/Application Support/Habitto/default.store
```

## 📍 Key Files

- **Schema V1:** `Core/Data/SwiftData/Migrations/HabittoSchemaV1.swift`
- **Migration Plan:** `Core/Data/SwiftData/Migrations/HabittoMigrationPlan.swift`
- **Container:** `Core/Data/SwiftData/SwiftDataContainer.swift`
- **Backup System:** `Core/Data/Backup/BackupManager.swift`

## ✅ Current Status

- **Schema Version:** 1.0.0 (baseline)
- **Migration System:** Active
- **Backup System:** Active
- **Corruption Detection:** Active
- **Status:** Production Ready ✅

---

**Last Updated:** 2024  
**Next Review:** Before any schema changes

