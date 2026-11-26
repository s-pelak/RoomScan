// ScanListView.swift
// RoomScanner — list of saved scans, with scan / rename / delete.

import SwiftUI

struct ScanListView: View {
    @EnvironmentObject private var store: RoomStore
    @State private var showingScanner = false
    @State private var renamingScan: RoomScan?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.scans.isEmpty {
                    ContentUnavailableView(
                        "No rooms scanned yet",
                        systemImage: "viewfinder",
                        description: Text("Scan your first room with LiDAR. The scan saves on this iPhone — nothing is uploaded.")
                    )
                } else {
                    List {
                        ForEach(store.scans) { scan in
                            NavigationLink(destination: ScanDetailView(scan: scan)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scan.name).font(.headline)
                                    Text(scan.sizeSummary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(scan.date.formatted(date: .abbreviated, time: .shortened)) · \(scan.furniture.count) furniture items")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Rename") {
                                    renamingScan = scan
                                    renameText = scan.name
                                }
                                .tint(.blue)
                                Button("Delete", role: .destructive) {
                                    store.delete(scan)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Room Scanner")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Room", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanFlowView()
            }
            .alert("Rename Room", isPresented: .constant(renamingScan != nil)) {
                TextField("Room name", text: $renameText)
                Button("Save") {
                    if var scan = renamingScan, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        scan.name = renameText.trimmingCharacters(in: .whitespaces)
                        store.save(scan)
                    }
                    renamingScan = nil
                }
                Button("Cancel", role: .cancel) { renamingScan = nil }
            }
        }
    }
}
