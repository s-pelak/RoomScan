// FurnitureEditorView.swift
// RoomScanner — add a furniture item by hand, or edit one RoomPlan found
// (rename it, fix its category, or correct its size). Sizes are entered
// in feet/inches and stored in metres.

import SwiftUI

struct FurnitureEditorView: View {
    @Binding var scan: RoomScan
    var item: FurnitureItem?
    var onSave: (RoomScan) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: FurnitureCategory = .other
    @State private var widthFeet: String = ""
    @State private var widthInches: String = ""
    @State private var depthFeet: String = ""
    @State private var depthInches: String = ""
    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""
    @State private var rotationDegrees: Double = 0

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. Road bike on trainer)", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(FurnitureCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }
                Section("Size") {
                    sizeRow(label: "Width", feet: $widthFeet, inches: $widthInches)
                    sizeRow(label: "Depth", feet: $depthFeet, inches: $depthInches)
                    sizeRow(label: "Height", feet: $heightFeet, inches: $heightInches)
                }
                Section("Position") {
                    HStack {
                        Text("Rotation")
                        Slider(value: $rotationDegrees, in: 0...360, step: 5)
                        Text("\(Int(rotationDegrees))°").frame(width: 44, alignment: .trailing)
                    }
                    Text("Position on the floor is set by RoomPlan for detected items. For hand-added items, place it near the room centre and move it in the rearrangement view — or leave it and fix it in Muse from the export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if isEditing {
                    Section {
                        Button("Remove Item", role: .destructive) {
                            if let item {
                                scan.furniture.removeAll { $0.id == item.id }
                                onSave(scan)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Furniture" : "Add Furniture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func sizeRow(label: String, feet: Binding<String>, inches: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("ft", text: feet)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
            Text("ft")
            TextField("in", text: inches)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
            Text("in")
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && metres(widthFeet, widthInches) > 0
            && metres(depthFeet, depthInches) > 0
            && metres(heightFeet, heightInches) > 0
    }

    private func metres(_ feet: String, _ inches: String) -> Double {
        RoomScan.metresFromFeetInches(feet: Int(feet) ?? 0, inches: Double(inches) ?? 0)
    }

    private func load() {
        guard let item else { return }
        name = item.name
        category = item.category
        rotationDegrees = item.rotationDegrees
        let (wf, wi) = feetInches(item.size.width)
        let (df, di) = feetInches(item.size.depth)
        let (hf, hi) = feetInches(item.size.height)
        widthFeet = "\(wf)"; widthInches = "\(wi)"
        depthFeet = "\(df)"; depthInches = "\(di)"
        heightFeet = "\(hf)"; heightInches = "\(hi)"
    }

    private func feetInches(_ metres: Double) -> (Int, Int) {
        let total = metres * 39.3701
        let feet = Int(total / 12)
        var inches = Int((total - Double(feet * 12)).rounded())
        var f = feet
        if inches == 12 { f += 1; inches = 0 }
        return (f, inches)
    }

    private func save() {
        let size = Size3(
            width: metres(widthFeet, widthInches),
            height: metres(heightFeet, heightInches),
            depth: metres(depthFeet, depthInches)
        )
        if var existing = item {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.category = category
            existing.size = size
            existing.rotationDegrees = rotationDegrees
            if let index = scan.furniture.firstIndex(where: { $0.id == existing.id }) {
                scan.furniture[index] = existing
            }
        } else {
            let newItem = FurnitureItem(
                id: UUID(),
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                position: Vec3(x: 0, y: 0, z: 0),
                size: size,
                rotationDegrees: rotationDegrees,
                detectedByRoomPlan: false,
                confidence: nil
            )
            scan.furniture.append(newItem)
        }
        onSave(scan)
        dismiss()
    }
}
