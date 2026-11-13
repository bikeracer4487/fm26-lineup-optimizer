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

    public init(directory: URL) { self.directory = directory }

    private struct Envelope<Value: Codable>: Codable {
        var version: Int
        var value: Value
    }

    private struct VersionOnly: Decodable { var version: Int }

    private func url(_ file: StoreFile) -> URL {
        directory.appendingPathComponent("\(file.rawValue).json")
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
        let reason: String
        do {
            let data = try Data(contentsOf: path)
            if (try? JSONSerialization.jsonObject(with: data)) == nil {
                reason = "it is not readable; it may have been cut short"
            } else if let header = try? JSONDecoder().decode(VersionOnly.self, from: data) {
                if header.version > Self.currentVersion {
                    reason = "it was saved by a newer version of the app"
                } else if let envelope = try? JSONDecoder().decode(Envelope<Value>.self, from: data) {
                    return Loaded(value: envelope.value, notice: nil)
                } else {
                    reason = "it does not hold what this version of the app expects"
                }
            } else {
                reason = "it is not in the form the app saves"
            }
        } catch {
            reason = "the file could not be read"
        }
        let keptAs = setAside(path, file: file)
        let tail = keptAs.map { "The unreadable copy was kept as \($0)." }
            ?? "The unreadable copy could not be moved aside and stays where it is."
        return Loaded(
            value: fresh,
            notice: "Could not use \(file.description) because \(reason), so \(file.startsWith). \(tail)")
    }

    /// Renames the file to `<name>.unreadable-<n>.json` with the first free number; the new name, or nil if it failed.
    private func setAside(_ path: URL, file: StoreFile) -> String? {
        let fileManager = FileManager.default
        var number = 1
        while true {
            let name = "\(file.rawValue).unreadable-\(number).json"
            let target = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: target.path) {
                do {
                    try fileManager.moveItem(at: path, to: target)
                    return name
                } catch {
                    return nil
                }
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
        try data.write(to: temporary)
        do {
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
