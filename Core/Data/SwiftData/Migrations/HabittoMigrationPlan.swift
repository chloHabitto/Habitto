import Foundation
import SwiftData

// MARK: - HabittoMigrationPlan

/// SwiftData migration plan for Habitto app
///
/// **Purpose:** Safely handle schema migrations between versions
/// **Current Version:** 1.0.0 (baseline)
///
/// **Migration Strategy:**
/// - Version 1 is the baseline (no migrations needed)
/// - Future versions will add migration stages here
/// - Supports both lightweight (automatic) and custom migrations
///
/// **Important Notes:**
/// - This handles SwiftData schema migrations (database structure changes)
/// - StorageHeader/MigrationRecord handle app-level data migrations (separate concern)
/// - Both systems work together but serve different purposes
struct HabittoMigrationPlan: SchemaMigrationPlan {
  // MARK: - SchemaMigrationPlan Conformance
  
  static var schemas: [any VersionedSchema.Type] {
    [
      HabittoSchemaV1.self
      // Future versions:
      // HabittoSchemaV2.self,
      // HabittoSchemaV3.self,
    ]
  }
  
  static var stages: [MigrationStage] {
    [
      // No migrations for V1 (it's the baseline)
      // Future migrations will be added here:
      // .lightweight(fromVersion: HabittoSchemaV1.self, toVersion: HabittoSchemaV2.self),
      // .custom(fromVersion: HabittoSchemaV2.self, toVersion: HabittoSchemaV3.self, willMigrate: { context in
      //   // Custom migration logic
      // })
    ]
  }
}

// MARK: - Migration Documentation

extension HabittoMigrationPlan {
  /// Get current schema version
  static var currentVersion: Schema.Version {
    HabittoSchemaV1.versionIdentifier
  }
  
  /// Check if migration is needed from a given version
  static func needsMigration(from version: Schema.Version) -> Bool {
    version < currentVersion
  }
  
  /// Get migration path information
  static func migrationPath(from fromVersion: Schema.Version, to toVersion: Schema.Version) -> String {
    "Migration from \(fromVersion) to \(toVersion)"
  }
}

// MARK: - Future Migration Examples (Documentation)

/*
 
 ## Example: Lightweight Migration (Automatic)
 
 When adding a new optional field or model, SwiftData can handle it automatically:
 
 ```swift
 // In HabittoSchemaV2.swift
 enum HabittoSchemaV2: VersionedSchema {
   static var versionIdentifier: Schema.Version {
     Schema.Version(2, 0, 0)
   }
   
   static var models: [any PersistentModel.Type] {
     HabittoSchemaV1.models + [
       NewModel.self  // New model added
     ]
   }
 }
 
 // In HabittoMigrationPlan.swift
 static var stages: [MigrationStage] {
   [
     .lightweight(fromVersion: HabittoSchemaV1.self, toVersion: HabittoSchemaV2.self)
   ]
 }
 ```
 
 ## Example: Custom Migration (Manual Data Transformation)
 
 When renaming fields, changing types, or transforming data:
 
 ```swift
 static var stages: [MigrationStage] {
   [
     .custom(
       fromVersion: HabittoSchemaV1.self,
       toVersion: HabittoSchemaV2.self,
       willMigrate: { context in
         // Fetch all HabitData records
         let descriptor = FetchDescriptor<HabitData>()
         let habits = try context.fetch(descriptor)
         
         // Transform data
         for habit in habits {
           // Example: Rename field or transform data
           // habit.newField = transformOldField(habit.oldField)
         }
         
         // Save changes
         try context.save()
       }
     )
   ]
 }
 ```
 
 ## Example: Removing Deprecated Model (SimpleHabitData)
 
 When removing SimpleHabitData in a future version:
 
 ```swift
 // In HabittoSchemaV2.swift
 enum HabittoSchemaV2: VersionedSchema {
   static var versionIdentifier: Schema.Version {
     Schema.Version(2, 0, 0)
   }
   
   static var models: [any PersistentModel.Type] {
     // Remove SimpleHabitData from the list
     HabittoSchemaV1.models.filter { $0 != SimpleHabitData.self }
   }
 }
 
 // Migration stage to clean up old data
 static var stages: [MigrationStage] {
   [
     .custom(
       fromVersion: HabittoSchemaV1.self,
       toVersion: HabittoSchemaV2.self,
       willMigrate: { context in
         // Delete all SimpleHabitData records
         let descriptor = FetchDescriptor<SimpleHabitData>()
         let legacyHabits = try context.fetch(descriptor)
         
         for legacyHabit in legacyHabits {
           context.delete(legacyHabit)
         }
         
         try context.save()
       }
     )
   ]
 }
 ```
 
 */

