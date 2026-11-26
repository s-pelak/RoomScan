// Exporter.swift
// RoomScanner — the Muse export. One Share button produces:
//   1. <name>.roomscan.json — human-readable, everything Muse needs to
//      rebuild the room as a Room Remix scene.json (positions in metres,
//      rotation in degrees, sizes in metres, plus a plain-text summary).
//   2. <name>-floorplan.png — a top-down floorplan image.
//   3. <name>.usdz — the RoomPlan 3D model, if the scan captured one.
// All three are handed to the iOS share sheet; nothing leaves the device
// unless the user explicitly shares it.

import Foundation
import SwiftUI
import UIKit

// MARK: - Muse-ready JSON model

struct MuseExport: Codable {
    struct Dimensions: Codable {
        var widthMetres: Double
        var depthMetres: Double
        var heightMetres: Double
        var widthFeetInches: String
        var depthFeetInches: String
        var heightFeetInches: String
    }

    struct Element: Codable {
        var id: String
        var kind: String
        var name: String
        var category: String?
        /// Centre position in metres. x = east, z = south, y = up.
        var positionMetres: Vec3
        /// Width (x) / height (y) / depth (z) in metres.
        var sizeMetres: Size3
        var rotationDegrees: Double
        var detectedByRoomPlan: Bool?
        var confidence: Double?
    }

    struct SceneItem: Codable {
        var id: String
        var name: String
        var category: String
        /// [width, height, depth] in metres — use directly as a scene size.
        var sizeMetres: [Double]
        /// [x, y, z] in metres — use directly as a scene position.
        var positionMetres: [Double]
        var rotationDegrees: Double
    }

    struct SceneMapping: Codable {
        var note: String
        var units: String
        var coordinateSystem: String
        var roomBoundsMetres: [String: Double]
        var items: [SceneItem]
    }

    var format: String = "roomscan"
    var formatVersion: Int = 1
    var app: String = "RoomScanner"
    var exportedAt: Date
    var roomName: String
    var scannedAt: Date
    var dimensions: Dimensions
    var summary: String
    var walls: [Element]
    var doors: [Element]
    var windows: [Element]
    var openings: [Element]
    var furniture: [Element]
    var scene: SceneMapping
}

enum MuseExporter {
    static func buildExport(for scan: RoomScan) -> MuseExport {
        let dims = MuseExport.Dimensions(
            widthMetres: scan.widthMetres,
            depthMetres: scan.depthMetres,
            heightMetres: scan.heightMetres,
            widthFeetInches: scan.widthFeetInches,
            depthFeetInches: scan.depthFeetInches,
            heightFeetInches: scan.heightFeetInches
        )

        let walls = scan.walls.map {
            MuseExport.Element(id: $0.id.uuidString, kind: "wall", name: "Wall",
                               category: nil, positionMetres: $0.position, sizeMetres: $0.size,
                               rotationDegrees: $0.rotationDegrees, detectedByRoomPlan: true, confidence: nil)
        }
        let doors = scan.doorsWindows.filter { $0.kind == .door }.map {
            MuseExport.Element(id: $0.id.uuidString, kind: "door", name: "Door",
                               category: nil, positionMetres: $0.position, sizeMetres: $0.size,
                               rotationDegrees: $0.rotationDegrees, detectedByRoomPlan: true, confidence: nil)
        }
        let windows = scan.doorsWindows.filter { $0.kind == .window }.map {
            MuseExport.Element(id: $0.id.uuidString, kind: "window", name: "Window",
                               category: nil, positionMetres: $0.position, sizeMetres: $0.size,
                               rotationDegrees: $0.rotationDegrees, detectedByRoomPlan: true, confidence: nil)
        }
        let openings = scan.doorsWindows.filter { $0.kind == .opening }.map {
            MuseExport.Element(id: $0.id.uuidString, kind: "opening", name: "Opening",
                               category: nil, positionMetres: $0.position, sizeMetres: $0.size,
                               rotationDegrees: $0.rotationDegrees, detectedByRoomPlan: true, confidence: nil)
        }
        let furniture = scan.furniture.map {
            MuseExport.Element(id: $0.id.uuidString, kind: "furniture", name: $0.displayName,
                               category: $0.category.rawValue, positionMetres: $0.position,
                               sizeMetres: $0.size, rotationDegrees: $0.rotationDegrees,
                               detectedByRoomPlan: $0.detectedByRoomPlan, confidence: $0.confidence)
        }

        // Bounds for Muse to centre the scene on.
        let xs = (scan.walls.map(\.position.x) + scan.furniture.map(\.position.x))
        let zs = (scan.walls.map(\.position.z) + scan.furniture.map(\.position.z))
        let bounds: [String: Double] = [
            "minX": xs.min() ?? 0, "maxX": xs.max() ?? 0,
            "minZ": zs.min() ?? 0, "maxZ": zs.max() ?? 0,
        ]

        let sceneItems = scan.furniture.map {
            MuseExport.SceneItem(
                id: $0.id.uuidString,
                name: $0.displayName,
                category: $0.category.rawValue,
                sizeMetres: [$0.size.width, $0.size.height, $0.size.depth],
                positionMetres: [$0.position.x, $0.position.y, $0.position.z],
                rotationDegrees: $0.rotationDegrees
            )
        }

        let scene = MuseExport.SceneMapping(
            note: """
            HOW MUSE SHOULD USE THIS FILE: Build a Room Remix scene.json from \
            this export. All sizes and positions are in METRES. For each item in \
            scene.items, use sizeMetres as [width, height, depth] and \
            positionMetres as [x, y, z] directly, and rotationDegrees as the \
            yaw. Centre the room by subtracting the midpoint of \
            roomBoundsMetres (min+max)/2 from every x and z, so the room is \
            centred on (0,0). Walls: use the walls array the same way \
            (length = max(sizeMetres.width, sizeMetres.depth)). Doors and \
            windows sit in the walls at their given positions. Do not guess \
            dimensions — use the numbers in this file.
            """,
            units: "metres",
            coordinateSystem: "x = east, z = south, y = up; origin = RoomPlan capture origin; rotationDegrees = yaw about the Y axis",
            roomBoundsMetres: bounds,
            items: sceneItems
        )

        var summaryLines = [
            "Room: \(scan.name)",
            "Size: \(scan.sizeSummary) (\(String(format: "%.2f", scan.widthMetres)) m × \(String(format: "%.2f", scan.depthMetres)) m, \(String(format: "%.2f", scan.heightMetres)) m high)",
            "Walls: \(scan.walls.count), Doors: \(doors.count), Windows: \(windows.count), Openings: \(openings.count)",
            "Furniture (\(scan.furniture.count) items):",
        ]
        for item in scan.furniture {
            summaryLines.append(
                "- \(item.displayName) (\(item.category.rawValue)): " +
                "\(String(format: "%.2f", item.size.width)) × \(String(format: "%.2f", item.size.depth)) m, " +
                "\(String(format: "%.2f", item.size.height)) m high, " +
                "at x \(String(format: "%.2f", item.position.x)) m, z \(String(format: "%.2f", item.position.z)) m, " +
                "rotated \(Int(item.rotationDegrees.rounded()))°" +
                (item.detectedByRoomPlan ? "" : " (added by hand)")
            )
        }

        return MuseExport(
            exportedAt: Date(),
            roomName: scan.name,
            scannedAt: scan.date,
            dimensions: dims,
            summary: summaryLines.joined(separator: "\n"),
            walls: walls,
            doors: doors,
            windows: windows,
            openings: openings,
            furniture: furniture,
            scene: scene
        )
    }

    /// Writes the JSON + floorplan PNG (+ USDZ if present) to a temp folder
    /// and returns the file URLs to share.
    static func exportFiles(for scan: RoomScan, store: RoomStore) throws -> [URL] {
        let safeName = scan.name
            .replacingOccurrences(of: "[^A-Za-z0-9-_ ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        let baseName = safeName.isEmpty ? "room" : safeName
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoomScannerExport-\(scan.id.uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let export = buildExport(for: scan)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(export)
        let jsonURL = folder.appendingPathComponent("\(baseName).roomscan.json")
        try jsonData.write(to: jsonURL)

        var urls: [URL] = [jsonURL]

        if let png = FloorplanRenderer.image(for: scan, size: CGSize(width: 1200, height: 1200)),
           let pngData = png.pngData() {
            let pngURL = folder.appendingPathComponent("\(baseName)-floorplan.png")
            try pngData.write(to: pngURL)
            urls.append(pngURL)
        }

        if let usdzName = scan.usdzFileName {
            let usdzURL = store.folder(for: scan).appendingPathComponent(usdzName)
            if FileManager.default.fileExists(atPath: usdzURL.path) {
                let copyURL = folder.appendingPathComponent("\(baseName).usdz")
                try? FileManager.default.copyItem(at: usdzURL, to: copyURL)
                if FileManager.default.fileExists(atPath: copyURL.path) { urls.append(copyURL) }
            }
        }

        return urls
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
