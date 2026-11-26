// RoomScannerApp.swift
// RoomScanner — app entry point. Requires a LiDAR-equipped iPhone/iPad
// (iPhone 12 Pro or later, including Stefan's iPhone 17 Pro Max).
// iOS 17.0+, SwiftUI, no third-party dependencies.

import SwiftUI

@main
struct RoomScannerApp: App {
    @StateObject private var store = RoomStore()

    var body: some Scene {
        WindowGroup {
            ScanListView()
                .environmentObject(store)
        }
    }
}
