import Foundation
import GRDB

extension AppDatabase {
    public struct Opened: Sendable {
        public let database: AppDatabase
        public let backupDirectory: URL?
    }

    private static let storeItemNames = [
        "clipsy.sqlite", "clipsy.sqlite-wal", "clipsy.sqlite-shm", "Payloads", "Thumbnails"
    ]

    /// only a damaged store is moved aside; any other failure is rethrown with no file changes
    public static func openRecoveringDamagedStore(directory: URL, now: Date = .now) throws -> Opened {
        try openRecoveringDamagedStore(directory: directory, migrator: migrator, now: now)
    }

    static func openRecoveringDamagedStore(
        directory: URL,
        migrator: DatabaseMigrator,
        now: Date
    ) throws -> Opened {
        do {
            return try Opened(database: AppDatabase(directory: directory, migrator: migrator), backupDirectory: nil)
        } catch let error as DatabaseError where isDamage(error) {
            let backup = try moveStoreAside(in: directory, now: now)
            return try Opened(database: AppDatabase(directory: directory, migrator: migrator), backupDirectory: backup)
        }
    }

    private static func isDamage(_ error: DatabaseError) -> Bool {
        error.resultCode == .SQLITE_CORRUPT || error.resultCode == .SQLITE_NOTADB
    }

    private static func moveStoreAside(in directory: URL, now: Date) throws -> URL {
        let stamp = now.formatted(
            Date.ISO8601FormatStyle(timeZone: .current)
                .year().month().day()
                .dateSeparator(.dash)
                .dateTimeSeparator(.space)
                .time(includingFractionalSeconds: false)
                .timeSeparator(.omitted)
        )
        let backup = directory
            .appending(path: "Backups", directoryHint: .isDirectory)
            .appending(path: "Damaged Store \(stamp)", directoryHint: .isDirectory)
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: backup,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        for name in storeItemNames {
            let item = directory.appending(path: name)
            guard fileManager.fileExists(atPath: item.path(percentEncoded: false)) else { continue }
            try fileManager.moveItem(at: item, to: backup.appending(path: name))
        }
        return backup
    }
}
