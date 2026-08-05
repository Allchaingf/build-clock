//
//  PersistenceManager.swift
//  CureClock
//
//  Offline persistence: a single Codable AppData JSON document in Documents,
//  written atomically and debounced. Photos are stored as separate blobs.
//  All iOS 14 safe (Foundation only).
//

import UIKit

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let fileName = "cureclock.json"

    /// All access to `pendingSave` and every disk write happens on this one queue.
    /// It used to be written from the main thread and cancelled from a global queue,
    /// which is an unsynchronised race on the same optional.
    private let queue = DispatchQueue(label: "com.curedclock.persistence")
    private var pendingSave: DispatchWorkItem?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var fileURL: URL { documentsURL.appendingPathComponent(fileName) }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: Load / Save

    func load() -> AppData {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(AppData.self, from: data) else {
            let seed = SampleData.empty()
            saveNow(seed)
            return seed
        }
        return decoded
    }

    /// Debounced save — coalesces rapid edits (typing) into one disk write.
    func save(_ data: AppData) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.pendingSave?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.write(data) }
            self.pendingSave = work
            self.queue.asyncAfter(deadline: .now() + 0.4, execute: work)
        }
    }

    /// Synchronous write — used on scenePhase background to guarantee no loss.
    func saveNow(_ data: AppData) {
        queue.sync {
            pendingSave?.cancel()
            pendingSave = nil
            write(data)
        }
    }

    private func write(_ data: AppData) {
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: fileURL, options: [.atomic])
    }

    func flush(_ data: AppData) { saveNow(data) }

    // MARK: Backup export / import

    /// Writes a timestamped copy to a temp URL for the share sheet.
    func exportBackup(_ data: AppData) -> URL? {
        guard let encoded = try? encoder.encode(data) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuilderClock-Backup.json")
        do { try encoded.write(to: url, options: [.atomic]); return url } catch { return nil }
    }

    /// Reads and validates a backup without touching the live document, so the user
    /// can be asked to confirm before anything is overwritten.
    func decodeBackup(from url: URL) -> AppData? {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AppData.self, from: data)
    }

    /// Commits a previously decoded backup over the live document.
    func commitBackup(_ data: AppData) { saveNow(data) }
}
