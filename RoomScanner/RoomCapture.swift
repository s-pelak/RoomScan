// RoomCapture.swift
// RoomScanner — LiDAR room capture using Apple's RoomPlan framework.
// Uses RoomCaptureView (Apple's out-of-the-box scanning UI: live contours,
// bottom 3D preview, on-screen guidance) plus RoomCaptureViewDelegate for
// the final post-processed CapturedRoom. The final room is converted into
// our own RoomScan model (metres) and, where possible, exported to USDZ
// with CapturedRoom.export(to:).

import Foundation
import RoomPlan
import SwiftUI
import UIKit
import simd

// MARK: - Conversion: CapturedRoom -> RoomScan

enum CapturedRoomConverter {
    static func roomScan(from captured: CapturedRoom, name: String) -> RoomScan {
        let walls: [Wall] = captured.walls.map { wall in
            Wall(
                id: wall.identifier,
                position: RoomGeometry.position(from: wall.transform),
                size: Size3(wall.dimensions),
                rotationDegrees: RoomGeometry.yawDegrees(from: wall.transform)
            )
        }

        var doorsWindows: [DoorWindow] = []
        doorsWindows += captured.doors.map {
            DoorWindow(id: $0.identifier, kind: .door,
                       position: RoomGeometry.position(from: $0.transform),
                       size: Size3($0.dimensions),
                       rotationDegrees: RoomGeometry.yawDegrees(from: $0.transform))
        }
        doorsWindows += captured.windows.map {
            DoorWindow(id: $0.identifier, kind: .window,
                       position: RoomGeometry.position(from: $0.transform),
                       size: Size3($0.dimensions),
                       rotationDegrees: RoomGeometry.yawDegrees(from: $0.transform))
        }
        doorsWindows += captured.openings.map {
            DoorWindow(id: $0.identifier, kind: .opening,
                       position: RoomGeometry.position(from: $0.transform),
                       size: Size3($0.dimensions),
                       rotationDegrees: RoomGeometry.yawDegrees(from: $0.transform))
        }

        let furniture: [FurnitureItem] = captured.objects.map { object in
            let category = FurnitureCategory.fromRoomPlan("\(object.category)")
            return FurnitureItem(
                id: object.identifier,
                name: category.displayName,
                category: category,
                position: RoomGeometry.position(from: object.transform),
                size: Size3(object.dimensions),
                rotationDegrees: RoomGeometry.yawDegrees(from: object.transform),
                detectedByRoomPlan: true,
                confidence: Double(object.confidence)
            )
        }

        // Overall room size from the bounding box of walls + furniture.
        let allX = walls.map(\.position.x) + furniture.map(\.position.x)
        let allZ = walls.map(\.position.z) + furniture.map(\.position.z)
        let width = (allX.max() ?? 0) - (allX.min() ?? 0)
        let depth = (allZ.max() ?? 0) - (allZ.min() ?? 0)
        let height = walls.map(\.size.height).max() ?? 2.4

        return RoomScan(
            id: UUID(),
            name: name,
            date: Date(),
            widthMetres: max(width, 0.5),
            depthMetres: max(depth, 0.5),
            heightMetres: max(height, 0.5),
            walls: walls,
            doorsWindows: doorsWindows,
            furniture: furniture,
            usdzFileName: nil
        )
    }
}

// MARK: - Coordinator (delegates)

final class ScanCoordinator: NSObject, ObservableObject {
    @Published var instruction: String = "Move slowly around the room."
    @Published var isScanning = false
    @Published var latestRoom: CapturedRoom?

    var onFinished: ((RoomScan, Data?) -> Void)?
    var onError: ((Error) -> Void)?

    private var captureView: RoomCaptureView?
    private var session: RoomCaptureSession?
    private let configuration = RoomCaptureSession.Configuration()

    func attach(to view: RoomCaptureView) {
        captureView = view
        let session = RoomCaptureSession(configuration: configuration, delegate: self)
        self.session = session
        view.captureSession = session
        view.delegate = self
    }

    func start() {
        session?.run(configuration: configuration)
        isScanning = true
    }

    func stop() {
        // Stopping triggers RoomCaptureViewDelegate's didPresent callback
        // with the post-processed CapturedRoom.
        session?.stop()
        isScanning = false
    }
}

// MARK: RoomCaptureSessionDelegate — live guidance

extension ScanCoordinator: RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        latestRoom = room
    }

    func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom) {
        latestRoom = room
    }

    func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom) {
        latestRoom = room
    }

    func captureSession(_ session: RoomCaptureSession, didRemove room: CapturedRoom) {
        latestRoom = room
    }

    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        // Friendly wording for the common instructions; fall back to the raw value.
        switch instruction {
        case .moveCloseToWall:
            self.instruction = "Move closer to a wall."
        case .moveAwayFromWall:
            self.instruction = "Move away from the wall a little."
        case .slowDown:
            self.instruction = "Slow down a little."
        case .turnOnLight:
            self.instruction = "Turn on more light in the room."
        case .lowTexture:
            self.instruction = "Point at something with more detail — a plain wall is hard to track."
        case .normal:
            self.instruction = "Looking good — keep moving slowly around the room."
        @unknown default:
            self.instruction = "Keep moving slowly around the room."
        }
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error { onError?(error) }
    }
}

// MARK: RoomCaptureViewDelegate — final result

extension ScanCoordinator: RoomCaptureViewDelegate {
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        // Let RoomPlan show its own post-processing UI, then deliver the result.
        if let error { onError?(error) }
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error { onError?(error); return }
        var scan = CapturedRoomConverter.roomScan(from: processedResult, name: "Untitled Room")
        var usdzData: Data?
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(scan.id.uuidString).usdz")
        do {
            try processedResult.export(to: tempURL)
            usdzData = try Data(contentsOf: tempURL)
            scan.usdzFileName = "\(scan.id.uuidString).usdz"
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            // USDZ export is a nice-to-have; the JSON scan is the core result.
            usdzData = nil
            scan.usdzFileName = nil
        }
        onFinished?(scan, usdzData)
    }
}

// MARK: - SwiftUI wrapper

struct RoomCaptureViewRepresentable: UIViewRepresentable {
    @ObservedObject var coordinator: ScanCoordinator

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
