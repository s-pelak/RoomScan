// RoomStore.swift
// RoomScanner — local persistence. Every scan is a folder in Documents/Scans/
// containing scan.json (+ an optional .usdz). No cloud, no account, no backend.

import Foundation

@MainActor
final class RoomStore: ObservableObject {
    @Published private(set) var scans: [RoomScan] = []

    private let scansDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        scansDirectory = docs.appendingPathComponent("Scans", isDirectory: true)
        try? FileManager.default.createDirectory(at: scansDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Load / save

    func load() {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: scansDirectory, includingPropertiesForKeys: nil)) ?? []
        var loaded: [RoomScan] = []
        for folder in folders where folder.hasDirectoryPath {
            let jsonURL = folder.appendingPathComponent("scan.json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let scan = try? JSONDecoder().decode(RoomScan.self, from: data) else { continue }
            loaded.append(scan)
        }
        scans = loaded.sorted { $0.date > $1.date }
    }

    func save(_ scan: RoomScan) {
        let folder = scansDirectory.appendingPathComponent(scan.id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(scan) else { return }
        try? data.write(to: folder.appendingPathComponent("scan.json"))
        if let index = scans.firstIndex(where: { $0.id == scan.id }) {
            scans[index] = scan
        } else {
            scans.insert(scan, at: 0)
        }
        scans.sort { $0.date > $1.date }
    }

    func delete(_ scan: RoomScan) {
        let folder = scansDirectory.appendingPathComponent(scan.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        scans.removeAll { $0.id == scan.id }
    }

    /// Folder a scan lives in (for its USDZ, if any).
    /// Pure computation over the immutable scans directory, so it is
    /// safe to call from non-main-actor code (e.g. MuseExporter).
    nonisolated func folder(for scan: RoomScan) -> URL {
        scansDirectory.appendingPathComponent(scan.id.uuidString, isDirectory: true)
    }

    /// Store a USDZ file next to a scan and record its name on the scan.
    func storeUSDZ(_ data: Data, fileName: String, for scan: inout RoomScan) {
        let folder = self.folder(for: scan)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent(fileName))
        scan.usdzFileName = fileName
    }
}
