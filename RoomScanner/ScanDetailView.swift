// ScanDetailView.swift
// RoomScanner — one saved scan: top-down floorplan, dimensions, furniture
// list, manual add/edit, and the Export for Muse button.

import SwiftUI

struct ScanDetailView: View {
    @EnvironmentObject private var store: RoomStore
    @State var scan: RoomScan
    @State private var showingFurnitureEditor = false
    @State private var editingItem: FurnitureItem?
    @State private var shareItems: [Any]?
    @State private var showingShare = false
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                floorplanCard
                dimensionsCard
                furnitureCard
            }
            .padding()
        }
        .navigationTitle(scan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportForMuse()
                } label: {
                    Label("Export for Muse", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $editingItem) { item in
            FurnitureEditorView(scan: $scan, item: item) { updated in
                store.save(updated)
            }
        }
        .sheet(isPresented: $showingFurnitureEditor) {
            FurnitureEditorView(scan: $scan, item: nil) { updated in
                store.save(updated)
            }
        }
        .sheet(isPresented: $showingShare) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
        }
        .alert("Export failed", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .onChange(of: scan) { updated in
            store.save(updated)
        }
    }

    // MARK: - Floorplan

    private var floorplanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Floorplan").font(.headline)
            if let image = FloorplanRenderer.image(for: scan, size: CGSize(width: 700, height: 700)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No floorplan — this scan has no walls or furniture.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Dimensions

    private var dimensionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Room").font(.headline)
            LabeledContent("Size", value: scan.sizeSummary)
            LabeledContent("Walls", value: "\(scan.walls.count)")
            LabeledContent("Doors", value: "\(scan.doorsWindows.filter { $0.kind == .door }.count)")
            LabeledContent("Windows", value: "\(scan.doorsWindows.filter { $0.kind == .window }.count)")
            LabeledContent("Openings", value: "\(scan.doorsWindows.filter { $0.kind == .opening }.count)")
            if scan.usdzFileName != nil {
                LabeledContent("3D model", value: "USDZ saved")
            }
        }
    }

    // MARK: - Furniture

    private var furnitureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Furniture (\(scan.furniture.count))").font(.headline)
                Spacer()
                Button("Add Item") { showingFurnitureEditor = true }
            }
            if scan.furniture.isEmpty {
                Text("RoomPlan didn't detect any furniture. Tap Add Item to add one by hand.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(scan.furniture) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName).font(.subheadline.bold())
                        Text("\(item.category.displayName) · \(feet(item.size.width)) × \(feet(item.size.depth)) ft, \(feet(item.size.height)) ft high")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.detectedByRoomPlan ? "Detected by RoomPlan" : "Added by hand")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { editingItem = item }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private func feet(_ metres: Double) -> String {
        String(format: "%.1f", metres * 3.28084)
    }

    // MARK: - Export

    private func exportForMuse() {
        do {
            let urls = try MuseExporter.exportFiles(for: scan, store: store)
            shareItems = urls as [Any]
            showingShare = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}
