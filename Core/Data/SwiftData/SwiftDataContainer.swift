import Foundation
import SwiftData
import OSLog

// MARK: - SwiftData Container Manager
@MainActor
final class SwiftDataContainer: ObservableObject {
    static let shared = SwiftDataContainer()
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftData")
    
    private init() {
        do {
            // Create the model container with all entities
            let schema = Schema([
                HabitData.self,
                CompletionRecord.self,
                DifficultyRecord.self,
                UsageRecord.self,
                HabitNote.self,
                StorageHeader.self,
                MigrationRecord.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.chloe-lee.Habitto")
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            self.modelContext = ModelContext(modelContainer)
            
            logger.info("SwiftData container initialized successfully")
            
            // Initialize storage header if needed
            initializeStorageHeader()
            
        } catch {
            logger.error("Failed to initialize SwiftData container: \(error.localizedDescription)")
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    // MARK: - Storage Header Management
    
    private func initializeStorageHeader() {
        let descriptor = FetchDescriptor<StorageHeader>()
        
        do {
            let headers = try modelContext.fetch(descriptor)
            
            if headers.isEmpty {
                // Create initial storage header
                let header = StorageHeader(schemaVersion: 1)
                modelContext.insert(header)
                
                try modelContext.save()
                logger.info("Created initial storage header with schema version 1")
            } else {
                logger.info("Storage header found with schema version: \(headers.first?.schemaVersion ?? 0)")
            }
        } catch {
            logger.error("Failed to initialize storage header: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Schema Version Management
    
    func getCurrentSchemaVersion() -> Int {
        let descriptor = FetchDescriptor<StorageHeader>()
        
        do {
            let headers = try modelContext.fetch(descriptor)
            return headers.first?.schemaVersion ?? 1
        } catch {
            logger.error("Failed to get schema version: \(error.localizedDescription)")
            return 1
        }
    }
    
    func updateSchemaVersion(to version: Int) {
        let descriptor = FetchDescriptor<StorageHeader>()
        
        do {
            let headers = try modelContext.fetch(descriptor)
            
            if let header = headers.first {
                header.schemaVersion = version
                header.lastMigration = Date()
            } else {
                let header = StorageHeader(schemaVersion: version)
                modelContext.insert(header)
            }
            
            try modelContext.save()
            logger.info("Updated schema version to \(version)")
        } catch {
            logger.error("Failed to update schema version: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Migration Management
    
    func recordMigration(from fromVersion: Int, to toVersion: Int, success: Bool, errorMessage: String? = nil) {
        let migrationRecord = MigrationRecord(
            fromVersion: fromVersion,
            toVersion: toVersion,
            success: success,
            errorMessage: errorMessage
        )
        
        modelContext.insert(migrationRecord)
        
        do {
            try modelContext.save()
            logger.info("Recorded migration from \(fromVersion) to \(toVersion), success: \(success)")
        } catch {
            logger.error("Failed to record migration: \(error.localizedDescription)")
        }
    }
    
    func getMigrationHistory() -> [MigrationRecord] {
        let descriptor = FetchDescriptor<MigrationRecord>(
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get migration history: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Data Integrity
    
    func validateDataIntegrity() -> Bool {
        // Check for orphaned records
        let habitDescriptor = FetchDescriptor<HabitData>()
        let completionDescriptor = FetchDescriptor<CompletionRecord>()
        
        do {
            let habits = try modelContext.fetch(habitDescriptor)
            let completions = try modelContext.fetch(completionDescriptor)
            
            // Check for orphaned completion records
            let habitIds = Set(habits.flatMap { $0.completionHistory.map { $0.persistentModelID } })
            let orphanedCompletions = completions.filter { !habitIds.contains($0.persistentModelID) }
            
            if !orphanedCompletions.isEmpty {
                logger.warning("Found \(orphanedCompletions.count) orphaned completion records")
                return false
            }
            
            logger.info("Data integrity validation passed")
            return true
            
        } catch {
            logger.error("Failed to validate data integrity: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Cleanup Operations
    
    func cleanupOrphanedRecords() {
        let habitDescriptor = FetchDescriptor<HabitData>()
        let completionDescriptor = FetchDescriptor<CompletionRecord>()
        let difficultyDescriptor = FetchDescriptor<DifficultyRecord>()
        let usageDescriptor = FetchDescriptor<UsageRecord>()
        let noteDescriptor = FetchDescriptor<HabitNote>()
        
        do {
            let habits = try modelContext.fetch(habitDescriptor)
            let completions = try modelContext.fetch(completionDescriptor)
            let difficulties = try modelContext.fetch(difficultyDescriptor)
            let usages = try modelContext.fetch(usageDescriptor)
            let notes = try modelContext.fetch(noteDescriptor)
            
            let habitIds = Set(habits.flatMap { $0.completionHistory.map { $0.persistentModelID } })
            
            // Remove orphaned records
            let orphanedCompletions = completions.filter { !habitIds.contains($0.persistentModelID) }
            let orphanedDifficulties = difficulties.filter { !habitIds.contains($0.persistentModelID) }
            let orphanedUsages = usages.filter { !habitIds.contains($0.persistentModelID) }
            let orphanedNotes = notes.filter { !habitIds.contains($0.persistentModelID) }
            
            for record in orphanedCompletions {
                modelContext.delete(record)
            }
            
            for record in orphanedDifficulties {
                modelContext.delete(record)
            }
            
            for record in orphanedUsages {
                modelContext.delete(record)
            }
            
            for record in orphanedNotes {
                modelContext.delete(record)
            }
            
            try modelContext.save()
            
            logger.info("Cleaned up \(orphanedCompletions.count) orphaned completion records")
            logger.info("Cleaned up \(orphanedDifficulties.count) orphaned difficulty records")
            logger.info("Cleaned up \(orphanedUsages.count) orphaned usage records")
            logger.info("Cleaned up \(orphanedNotes.count) orphaned note records")
            
        } catch {
            logger.error("Failed to cleanup orphaned records: \(error.localizedDescription)")
        }
    }
}
