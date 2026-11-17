import CryptoKit
import Foundation

public enum Payload: Sendable, Equatable {
    case inline(Data)
    case file(hash: String)
}

public struct PayloadStore: Sendable {
    public static let inlineLimit = 4096

    let payloadsDirectory: URL
    let thumbnailsDirectory: URL

    public init(directory: URL) {
        payloadsDirectory = directory.appending(path: "Payloads", directoryHint: .isDirectory)
        thumbnailsDirectory = directory.appending(path: "Thumbnails", directoryHint: .isDirectory)
    }

    public func store(_ data: Data) throws -> Payload {
        guard data.count >= Self.inlineLimit else { return .inline(data) }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = fileURL(for: hash)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) == false else {
            return .file(hash: hash)
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: .atomic)
        return .file(hash: hash)
    }

    public func data(for payload: Payload) throws -> Data {
        switch payload {
        case let .inline(data):
            data
        case let .file(hash):
            try Data(contentsOf: fileURL(for: hash))
        }
    }

    /// referenced must hold both payload hashes and card content hashes (hex), or thumbnails are deleted
    public func collectGarbage(referenced: Set<String>) throws {
        for file in try files(in: payloadsDirectory, recursive: true)
            where referenced.contains(file.lastPathComponent) == false
        {
            try FileManager.default.removeItem(at: file)
        }
        for file in try files(in: thumbnailsDirectory, recursive: false)
            where referenced.contains(file.deletingPathExtension().lastPathComponent) == false
        {
            try FileManager.default.removeItem(at: file)
        }
    }

    func fileURL(for hash: String) -> URL {
        payloadsDirectory
            .appending(path: String(hash.prefix(2)), directoryHint: .isDirectory)
            .appending(path: hash, directoryHint: .notDirectory)
    }

    private func files(in directory: URL, recursive: Bool) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return [] }
        let options: FileManager.DirectoryEnumerationOptions = recursive ? [] : [.skipsSubdirectoryDescendants]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else { return [] }
        return try enumerator.compactMap { element in
            guard let url = element as? URL,
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            else { return nil }
            return url
        }
    }
}
