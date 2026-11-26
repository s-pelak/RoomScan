# Room Scanner — native iOS LiDAR room scanner

A native SwiftUI app that scans a room with your iPhone's LiDAR (Apple's
RoomPlan framework), saves the room — dimensions, walls, doors, windows and
furniture — on the device, and exports a Muse-ready file you can send to
Muse so it can rebuild the room as a rearrangeable 3D scene.

**No third-party dependencies. No backend, no account, no analytics.
Everything stays on your iPhone unless you explicitly share an export.**

## What it does

- **Scan a room** — Walk slowly around the room with your iPhone. RoomPlan
  outlines the walls, doors, windows and furniture live, with on-screen
  guidance ("move closer to a wall", "slow down", …). Tap **Stop & Save Scan**.
- **Save scans locally** — Each scan is stored in the app's Documents folder
  (`Scans/<scan-id>/scan.json`, plus a `.usdz` 3D model when RoomPlan exports
  one). List, rename and delete scans from the main screen.
- **Room dimensions** — Overall size is computed from the scan (shown in
  feet/inches, stored in metres), plus per-wall lengths, door/window sizes
  and positions, and every detected furniture item with its category,
  dimensions, position and rotation.
- **Manual furniture** — RoomPlan only detects certain categories (bed, sofa,
  chair, table, desk, storage, TV, bath, oven, fridge, stove, washer/dryer,
  dishwasher, sink, toilet, fireplace, …). It will **not** reliably detect a
  bike on a trainer, a pull-up rack, a spare wheel, or clutter. For anything
  it misses or mislabels, tap **Add Item** / **Edit** on the scan detail
  screen and add it by hand (name, category, width/depth/height in ft/in,
  rotation). Hand-added items are marked as such in the export.
- **Top-down floorplan** — Each scan shows a floorplan view in the app, and
  the export includes a floorplan PNG.
- **Export for Muse (the important bit)** — On a scan, tap **Export for
  Muse**. The iOS share sheet offers three files:
  1. `<room>.roomscan.json` — human-readable JSON with everything Muse needs:
     room name, dimensions (metres + ft/in), walls, doors, windows, openings,
     furniture with exact dimensions/positions/rotations, a plain-text
     `summary`, and a `scene` block with a note telling Muse exactly how to
     turn it into a Room Remix `scene.json` (sizes/positions in metres,
     rotation in degrees, room bounds to centre on).
  2. `<room>-floorplan.png` — top-down floorplan image.
  3. `<room>.usdz` — the RoomPlan 3D model, when available.

  Share the `.roomscan.json` to Muse (Messages, Mail, Files, AirDrop — or
  just upload it in chat) and say what you want rearranged. Muse reads the
  dimensions straight from the file instead of guessing from a photo.

## Requirements

- **iPhone with LiDAR** — iPhone 12 Pro or later. Stefan's iPhone 17 Pro Max
  has LiDAR. RoomPlan does not work on non-LiDAR iPhones.
- **iOS 17.0+** on the phone, **Xcode 15+** on the Mac.
- **Your own Apple Developer account** (free Apple ID signing works for
  installing on your own phone; a paid developer account is only needed for
  TestFlight/App Store distribution).

## Build & install (on your MacBook)

1. Copy this whole `room-scanner-ios` folder to your MacBook (AirDrop, USB,
   or git — whichever you like).
2. Open `RoomScanner.xcodeproj` in Xcode.
3. In the project editor, select the **RoomScanner** target → **Signing &
   Capabilities**:
   - Tick **Automatically manage signing**.
   - Set **Team** to your Apple Developer account / Apple ID.
   - **Bundle Identifier** is `com.stefan.roomscan` — change it if you
     already use that ID, or leave it as is.
4. Plug in your iPhone 17 Pro Max (or select it from Xcode's device menu
   at the top). If Xcode asks, trust the computer on the phone.
5. Press **Run** (▶, or Cmd+R). Xcode builds the app and installs it on
   your phone. The first launch asks for camera permission — allow it
   (LiDAR room capture needs the camera).
6. If Xcode complains about signing ("failed to register bundle identifier"
   or similar), change the Bundle Identifier to something unique, e.g.
   `com.stefan.roomscan2`, and try again.

## How to scan a room

1. Open the app, tap **Scan Room**, type a room name (e.g. "Guest Bedroom").
2. Tap **Start Scanning**. Hold the phone up and walk slowly around the
   room, pointing at each wall. Keep going until every wall is outlined —
   don't rush, and turn the lights on.
3. Tap **Stop & Save Scan**. The app saves the scan and shows its size.
4. Open the scan to check the floorplan and furniture list. Fix anything
   RoomPlan missed with **Add Item** / **Edit** — especially the bike on the
   trainer and the pull-up rack, which RoomPlan won't recognise as furniture.
5. Tap **Export for Muse** and share the `.roomscan.json` to Muse.

Tips for a good scan: clear the floor a little if you can, keep the phone
at chest height, move slowly, and scan each wall from about 1–2 metres away.
A second slow pass around the room usually fills in anything missed.

## How to send a scan to Muse

- In the app: open the scan → **Export for Muse** → share the
  `.roomscan.json` file (AirDrop to your Mac, save to Files, or send it to
  yourself in Messages/Mail), then upload/attach it in your chat with Muse.
- Or in Files on your iPhone: the scans also live in the app's Documents
  folder, but the share sheet is the intended route — it bundles the JSON,
  floorplan PNG and USDZ together.

## Project layout

```
RoomScanner.xcodeproj/          Xcode project (open this)
RoomScanner/
  RoomScannerApp.swift          App entry point
  Models.swift                  RoomScan / Wall / DoorWindow / FurnitureItem
                                (all dimensions in metres; ft/in is display only)
  RoomStore.swift               Local save/load/delete (Documents/Scans/)
  RoomCapture.swift             RoomPlan wrapper: RoomCaptureView, session
                                delegates, CapturedRoom -> RoomScan conversion,
                                USDZ export via CapturedRoom.export(to:)
  ScanFlowView.swift            Name → scan → save flow
  ScanListView.swift            List of saved scans, rename/delete
  ScanDetailView.swift          Floorplan, dimensions, furniture, Export button
  FurnitureEditorView.swift     Add/edit furniture by hand (ft/in entry)
  FloorplanRenderer.swift       Top-down floorplan drawing (app + PNG export)
  Exporter.swift                Muse-ready .roomscan.json + share sheet
  Info.plist                    Camera permission text, ARKit requirement
  Assets.xcassets/              App icon set (add your own icon images)
```

## Limitations (honest ones)

- **LiDAR only.** No LiDAR = no scan. iPads with LiDAR also work.
- **RoomPlan detects bounding boxes, not exact shapes.** A bed is a box
  with a category, not a detailed model. Furniture dimensions are
  approximate (± a few cm) — good enough to plan a layout, not for
  millimetre-accurate fitting.
- **It won't detect everything.** Bikes, trainers, pull-up racks, spare
  wheels, clutter, plants and small items are usually missed or lumped in
  as generic objects. Add those by hand in the app — that's what the
  manual editor is for.
- **One room per scan.** Scan each room separately (office, guest bedroom,
  master bedroom) and export each one.
- **No in-app rearrangement editor (yet).** This app scans, saves and
  exports. The rearranging happens with Muse from the export — that's the
  workflow you asked for ("export the room to you so you can build the
  rearrangement system"). If you later want a built-in drag-to-move
  floorplan editor in the app itself, that is a separate feature to add on
  top of these same models.
- **USDZ export is best-effort.** If RoomPlan can't export a USDZ for a
  scan, the JSON + floorplan still export fine — those are the files Muse
  actually uses.
- **Not verified on a real device here.** This project was written and
  structure-checked on a Linux machine with no Xcode/Swift toolchain, so
  it has **not** been compiled or run on an iPhone yet. Open it in Xcode
  on your MacBook and build it — if Xcode flags anything (usually a
  RoomPlan API name that shifted between iOS versions), tell Muse the exact
  error and it can be fixed in one pass. The RoomPlan calls used here
  (`RoomCaptureView`, `RoomCaptureSession.run(configuration:)`,
  `RoomCaptureViewDelegate`, `CapturedRoom.export(to:)`) are the documented
  iOS 17 APIs.
