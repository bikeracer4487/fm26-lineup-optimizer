import Foundation

public enum StoreFile: String, CaseIterable, Sendable {
    case settings, tactics, fixtures, history, squad

    /// How a notice refers to the file, in the owner's words.
    var description: String {
        switch self {
        case .settings: "your settings"
        case .tactics: "your tactics"
        case .fixtures: "your saved fixtures"
        case .history: "the confirmed lineups"
        case .squad: "the squad"
        }
    }

    /// What the app starts with when there is nothing saved.
    var startsWith: String {
        switch self {
        case .settings: "the settings start at their defaults"
        case .tactics: "the list starts empty"
        case .fixtures: "the list starts empty"
        case .history: "the list starts empty"
        case .squad: "the squad starts empty"
        }
    }

    var missingSubject: String {
        switch self {
        case .settings: "saved settings"
        case .tactics: "saved tactics"
        case .fixtures: "saved fixtures"
        case .history: "confirmed lineups"
        case .squad: "saved squad"
        }
    }
}

public struct Loaded<Value> {
    public let value: Value
    public let notice: String?

    public init(value: Value, notice: String?) {
        self.value = value; self.notice = notice
    }
}

/// Reads and writes the app's files under one directory. Each file is `{"version": 1, "value": ...}`.
public struct Store: Sendable {
    static let currentVersion = 1
    let directory: URL
    private let move: @Sendable (URL, URL) throws -> Void
    private let copy: @Sendable (URL, URL) throws -> Void

    public init(directory: URL) {
        self.init(
            directory: directory,
            move: { try FileManager.default.moveItem(at: $0, to: $1) },
            copy: { try FileManager.default.copyItem(at: $0, to: $1) })
    }

    /// File operations are injectable so tests can make them fail.
    init(
        directory: URL,
        move: @escaping @Sendable (URL, URL) throws -> Void,
        copy: @escaping @Sendable (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) }
    ) {
        self.directory = directory; self.move = move; self.copy = copy
    }

    /// The file's name at the start of a sentence.
    private func subject(_ file: StoreFile) -> String {
        let text = file.description
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private struct Envelope<Value: Codable>: Codable {
        var version: Int
        var value: Value
    }

    private struct VersionOnly: Decodable { var version: Int }

    private func url(_ file: StoreFile) -> URL {
        directory.appendingPathComponent("\(file.rawValue).json")
    }

    /// Whether the file is on disk, readable or not.
    func exists(_ file: StoreFile) -> Bool {
        FileManager.default.fileExists(atPath: url(file).path)
    }

    public func load<Value: Codable>(_ file: StoreFile, as: Value.Type, otherwise fresh: Value) -> Loaded<Value> {
        let fileManager = FileManager.default
        let path = url(file)
        guard fileManager.fileExists(atPath: path.path) else {
            let others = StoreFile.allCases.filter { $0 != file }
            let beside = others.contains { fileManager.fileExists(atPath: url($0).path) }
            let notice = beside
                ? "No \(file.missingSubject) were found, so \(file.startsWith)."
                : nil
            return Loaded(value: fresh, notice: notice)
        }
        let newer: Bool
        do {
            let data = try Data(contentsOf: path)
            if let header = try? JSONDecoder().decode(VersionOnly.self, from: data),
               header.version >= 1, header.version <= Self.currentVersion,
               let envelope = try? JSONDecoder().decode(Envelope<Value>.self, from: data) {
                return Loaded(value: envelope.value, notice: nil)
            }
            if let header = try? JSONDecoder().decode(VersionOnly.self, from: data) {
                newer = header.version > Self.currentVersion
            } else {
                newer = false
            }
        } catch {
            newer = false
        }
        let kept = setAside(path, file: file)
        let tail = kept.map { "The unreadable file was kept as \($0)." }
            ?? "The unreadable file could not be kept aside and will be replaced the next time that part of the app is saved."
        let lead = newer
            ? "The file holding \(file.description) comes from a newer version of the app, so \(file.startsWith)."
            : "\(subject(file)) could not be read as saved data (the file may have been cut short), so \(file.startsWith)."
        return Loaded(value: fresh, notice: "\(lead) \(tail)")
    }

    /// Keeps the file as `<name>.unreadable-<n>.json` with the first free number, by moving it or, if that
    /// fails, copying it; the new name, or nil if neither worked.
    private func setAside(_ path: URL, file: StoreFile) -> String? {
        let fileManager = FileManager.default
        var number = 1
        while true {
            let name = "\(file.rawValue).unreadable-\(number).json"
            let target = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: target.path) {
                if (try? move(path, target)) != nil { return name }
                if (try? copy(path, target)) != nil { return name }
                return nil
            }
            number += 1
        }
    }

    public func save<Value: Codable>(_ value: Value, to file: StoreFile) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(Envelope(version: Self.currentVersion, value: value))
        let temporary = directory.appendingPathComponent(".\(file.rawValue).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary)
            if fileManager.fileExists(atPath: url(file).path) {
                _ = try fileManager.replaceItemAt(url(file), withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: url(file))
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }
}
