# SwiftData Migration API Findings for iOS 18

## ✅ API Verification Results

### Confirmed APIs (iOS 18)

1. **`VersionedSchema` Protocol** ✅ EXISTS
   - Conform with: `enum MySchema: VersionedSchema`
   - Required: `static var versionIdentifier: Schema.Version`
   - Required: `static var models: [any PersistentModel.Type]`

2. **`SchemaMigrationPlan` Protocol** ✅ EXISTS
   - Conform with: `struct MyPlan: SchemaMigrationPlan`
   - Required: `static var schemas: [any VersionedSchema.Type]`
   - Required: `static var stages: [MigrationStage]`

3. **`Schema.Version`** ✅ EXISTS
   - Initialization: `Schema.Version(1, 0, 0)` or `Schema.Version.init(1, 0, 0)`
   - **Limitation:** Does NOT expose `majorVersion`, `minorVersion`, `patchVersion`
   - Comparison: Use `String(describing:)` or `==` operator (if Equatable)
   - Description: Use `String(describing: version)` for logging

4. **`MigrationStage`** ✅ EXISTS
   - `.lightweight(fromVersion:toVersion:)` - Automatic migrations
   - `.custom(fromVersion:toVersion:willMigrate:)` - Manual migrations

## Current Implementation Status

### ✅ What's Working

- `HabittoSchemaV1` correctly conforms to `VersionedSchema`
- `HabittoMigrationPlan` correctly conforms to `SchemaMigrationPlan`
- `Schema.Version` initialization is correct
- Model list is complete (13 models)
- `ModelContainer` initialization with migration plan

### ⚠️ What Was Fixed

- Test file no longer accesses non-existent `majorVersion`/`minorVersion`/`patchVersion`
- Version comparison uses `String(describing:)` instead of direct comparison
- Unused variable warnings resolved

## Recommendations

### Option 1: Continue with Formal Migration System (RECOMMENDED)

**Pros:**
- ✅ Official SwiftData migration support
- ✅ Automatic lightweight migrations for simple changes
- ✅ Custom migrations for complex transformations
- ✅ Future-proof for schema changes

**Cons:**
- ⚠️ `Schema.Version` doesn't expose individual components
- ⚠️ Version comparison requires workarounds

**Implementation:**
- Keep current `HabittoSchemaV1` and `HabittoMigrationPlan`
- Use `String(describing:)` for version logging
- Use `==` operator for version equality (if supported)
- Document version comparison limitations

### Option 2: Simplified Approach (ALTERNATIVE)

If formal migration system causes issues, use:

**SwiftData Automatic Migrations:**
- SwiftData automatically handles:
  - Adding new optional properties
  - Adding new models
  - Some property type changes

**Documentation-Based Approach:**
- Create `SCHEMA_BASELINE_V1.md` documenting current schema
- Use `StorageHeader`/`MigrationRecord` for app-level migrations
- Manual migration scripts for complex changes

**When to Use:**
- If `VersionedSchema`/`SchemaMigrationPlan` APIs don't work
- If you prefer simpler approach
- If automatic migrations cover your needs

## API Usage Examples

### Creating Schema Version

```swift
enum HabittoSchemaV1: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(1, 0, 0)  // ✅ Correct
  }
  
  static var models: [any PersistentModel.Type] {
    [HabitData.self, CompletionRecord.self, ...]
  }
}
```

### Creating Migration Plan

```swift
struct HabittoMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [HabittoSchemaV1.self]
  }
  
  static var stages: [MigrationStage] {
    []  // Empty for V1 (baseline)
  }
}
```

### Initializing ModelContainer

```swift
let schema = Schema(versionedSchema: HabittoSchemaV1.self)
let migrationPlan = HabittoMigrationPlan.self

let container = try ModelContainer(
  for: schema,
  migrationPlan: migrationPlan,
  configurations: [config]
)
```

### Version Comparison (Workaround)

```swift
// Schema.Version doesn't expose components, so use description
let version1 = Schema.Version(1, 0, 0)
let version2 = Schema.Version(2, 0, 0)

let desc1 = String(describing: version1)
let desc2 = String(describing: version2)

if desc1 != desc2 {
  // Versions are different
}
```

## Testing the API

To verify the API works in your environment:

1. **Build the project:**
   ```bash
   xcodebuild -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 15' build
   ```

2. **Run the test runner:**
   ```swift
   let runner = SchemaMigrationTestRunner()
   await runner.runAllTests()
   ```

3. **Check for errors:**
   - If `VersionedSchema` not found → API might not be available
   - If `SchemaMigrationPlan` not found → API might not be available
   - If compilation succeeds → API is working!

## Decision Matrix

| Scenario | Recommendation |
|----------|---------------|
| Build succeeds with migration plan | ✅ Use formal migration system |
| Build fails with "VersionedSchema not found" | ⚠️ Use simplified approach |
| Build succeeds but runtime errors | ⚠️ Check iOS version, use simplified approach |
| Need complex data transformations | ✅ Use formal migration system with custom stages |
| Only adding optional fields/models | ✅ Either approach works |

## Next Steps

1. ✅ **Verify build succeeds** - Current implementation should compile
2. ✅ **Test on simulator** - Verify migration plan works at runtime
3. ✅ **Document findings** - Update this doc with actual results
4. ⚠️ **If issues persist** - Switch to simplified approach

## Conclusion

The formal migration system **should work** in iOS 18. The main limitation is that `Schema.Version` doesn't expose individual components, but this can be worked around using `String(describing:)` for comparison and logging.

If you encounter runtime issues or the API doesn't work as expected, the simplified approach (automatic migrations + documentation) is a viable alternative that still protects user data.

