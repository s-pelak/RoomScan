// Models.swift
// RoomScanner — data model for a saved room scan.
// All dimensions are stored in METRES internally (RoomPlan's native unit).
// Feet/inches are only a display conversion, so exports stay exact.

import Foundation
import simd

// MARK: - Furniture categories

/// Categories RoomPlan can detect, plus a generic fallback for manual items.
/// Raw values are the human-readable names used in the export JSON.
enum FurnitureCategory: String, Codable, CaseIterable, Identifiable {
    case bed, sofa, chair, armchair, table, desk, storage, dresser, cabinet
    case television, bathtub, oven, refrigerator, stove, washerDryer
    case dishwasher, sink, toilet, fireplace, exerciseBike, bike, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .washerDryer: return "Washer / Dryer"
        case .exerciseBike: return "Exercise Bike"
        case .television: return "TV"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// Map a RoomPlan object-category string (e.g. "bed", "sofa") to a category.
    static func fromRoomPlan(_ raw: String) -> FurnitureCategory {
        let key = raw.lowercased().replacingOccurrences(of: " ", with: "")
        switch key {
        case "bed": return .bed
        case "sofa", "couch": return .sofa
        case "chair": return .chair
        case "armchair": return .armchair
        case "table": return .table
        case "desk": return .desk
        case "storage", "shelf", "shelving", "bookcase": return .storage
        case "dresser": return .dresser
        case "cabinet": return .cabinet
        case "television", "tv": return .television
        case "bathtub", "bath": return .bathtub
        case "oven": return .oven
        case "refrigerator", "fridge": return .refrigerator
        case "stove": return .stove
        case "washerdryer", "washer", "dryer": return .washerDryer
        case "dishwasher": return .dishwasher
        case "sink": return .sink
        case "toilet": return .toilet
        case "fireplace": return .fireplace
        default: return .other
        }
    }
}

// MARK: - Geometry helpers (metres)

/// A point on the floor plan. x = east, z = south, y = up. Origin is the
/// RoomPlan capture origin; Muse re-centres it when building a scene.
struct Vec3: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vec3(x: 0, y: 0, z: 0)

    init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
    init(_ v: SIMD3<Float>) { self.x = Double(v.x); self.y = Double(v.y); self.z = Double(v.z) }
}

/// Width (x) / height (y) / depth (z), in metres.
struct Size3: Codable, Equatable {
    var width: Double
    var height: Double
    var depth: Double

    init(width: Double, height: Double, depth: Double) {
        self.width = width; self.height = height; self.depth = depth
    }
    init(_ v: SIMD3<Float>) {
        self.width = Double(v.x); self.height = Double(v.y); self.depth = Double(v.z)
    }
}

// MARK: - Room elements

struct Wall: Codable, Identifiable, Equatable {
    var id: UUID
    /// Centre of the wall, metres.
    var position: Vec3
    /// Length (x) / height (y) / thickness (z), metres.
    var size: Size3
    /// Yaw in degrees, 0 = wall runs along the x-axis.
    var rotationDegrees: Double

    var lengthMetres: Double { max(size.width, size.depth) }
}

struct DoorWindow: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case door, window, opening }
    var id: UUID
    var kind: Kind
    var position: Vec3
    var size: Size3
    var rotationDegrees: Double
}

struct FurnitureItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var category: FurnitureCategory
    /// Centre of the item on the floor, metres.
    var position: Vec3
    /// Width (x) / height (y) / depth (z), metres.
    var size: Size3
    /// Yaw in degrees, 0 = item faces +z (south in the capture frame).
    var rotationDegrees: Double
    /// True when RoomPlan detected it, false when added by hand.
    var detectedByRoomPlan: Bool
    /// RoomPlan confidence 0...1, nil for manual items.
    var confidence: Double?

    var displayName: String { name.isEmpty ? category.displayName : name }
}

// MARK: - The saved scan

struct RoomScan: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var date: Date
    /// Overall room size, metres. Computed from the walls at capture time;
    /// recomputed whenever walls change.
    var widthMetres: Double
    var depthMetres: Double
    var heightMetres: Double
    var walls: [Wall]
    var doorsWindows: [DoorWindow]
    var furniture: [FurnitureItem]
    /// File name of the exported USDZ inside the scan's folder, if captured.
    var usdzFileName: String?

    // MARK: Display conversions (feet/inches, for humans only)

    var widthFeetInches: String { Self.feetInches(widthMetres) }
    var depthFeetInches: String { Self.feetInches(depthMetres) }
    var heightFeetInches: String { Self.feetInches(heightMetres) }

    var sizeSummary: String {
        "\(widthFeetInches) × \(depthFeetInches), \(heightFeetInches) high"
    }

    static func feetInches(_ metres: Double) -> String {
        let totalInches = metres * 39.3701
        let feet = Int(totalInches / 12)
        let inches = Int((totalInches - Double(feet * 12)).rounded())
        if inches == 12 { return "\(feet + 1) ft 0 in" }
        return "\(feet) ft \(inches) in"
    }

    static func metresFromFeetInches(feet: Int, inches: Double) -> Double {
        (Double(feet) * 12 + inches) * 0.0254
    }
}

// MARK: - Transform helpers (RoomPlan -> model)

enum RoomGeometry {
    /// Yaw (rotation about the vertical Y axis) in degrees, from a 4x4 transform.
    static func yawDegrees(from transform: simd_float4x4) -> Double {
        let yaw = atan2(transform.columns.2.x, transform.columns.2.z)
        return Double(yaw) * 180 / .pi
    }

    static func position(from transform: simd_float4x4) -> Vec3 {
        Vec3(transform.columns.3.xyz)
    }
}

extension simd_float4 {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
