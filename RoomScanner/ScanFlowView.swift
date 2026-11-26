// ScanFlowView.swift
// RoomScanner — the scan flow: name the room, scan with LiDAR, review,
// save. The capture view is Apple's RoomCaptureView, so the live guidance
// ("move closer to a wall", etc.) comes from RoomPlan itself.

import SwiftUI
import RoomPlan

struct ScanFlowView: View {
    @EnvironmentObject private var store: RoomStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = ScanCoordinator()
    @State private var roomName: String = ""
    @State private var phase: Phase = .naming
    @State private var savedScan: RoomScan?
    @State private var errorMessage: String?

    enum Phase { case naming, scanning, done }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .naming:
                    namingView
                case .scanning:
                    scanningView
                case .done:
                    doneView
                }
            }
            .navigationTitle("Scan a Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Scan failed", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil; phase = .naming }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            coordinator.onFinished = { scan, usdzData in
                var named = scan
                named.name = roomName.isEmpty ? "Untitled Room" : roomName
                if let usdzData {
                    store.storeUSDZ(usdzData, fileName: "\(named.id.uuidString).usdz", for: &named)
                }
                store.save(named)
                savedScan = named
                phase = .done
            }
            coordinator.onError = { error in
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Name first

    private var namingView: some View {
        Form {
            Section {
                TextField("Room name", text: $roomName)
                    .autocorrectionDisabled()
                Text("Example: Guest Bedroom, Office, Master Bedroom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Walk slowly around the room, pointing your iPhone at each wall. RoomPlan needs a LiDAR-equipped iPhone — your iPhone 17 Pro Max has one. Keep moving until every wall is outlined, then tap Stop.")
                    .font(.callout)
            }
            Section {
                Button("Start Scanning") {
                    phase = .scanning
                    // Small delay so the capture view is on screen before run().
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        coordinator.start()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Live scan

    private var scanningView: some View {
        VStack(spacing: 0) {
            RoomCaptureViewRepresentable(coordinator: coordinator)
                .ignoresSafeArea(edges: .bottom)
            VStack(spacing: 12) {
                Text(coordinator.instruction)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Stop & Save Scan") {
                    coordinator.stop()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Scan saved")
                .font(.title2.bold())
            if let scan = savedScan {
                Text("\(scan.name) — \(scan.sizeSummary)")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("\(scan.walls.count) walls · \(scan.furniture.count) furniture items detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                NavigationLink("View & Export") {
                    ScanDetailView(scan: scan)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
