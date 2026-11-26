// FloorplanRenderer.swift
// RoomScanner — top-down floorplan drawing (used in the detail view and
// exported as <name>-floorplan.png). North is up on the page; x runs
// left-to-right, z runs top-to-bottom.

import UIKit

enum FloorplanRenderer {
    /// Draws the room top-down into an image. Returns nil if there is nothing to draw.
    static func image(for scan: RoomScan, size: CGSize) -> UIImage? {
        guard !scan.walls.isEmpty || !scan.furniture.isEmpty else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            draw(scan: scan, in: context.cgContext, size: size)
        }
    }

    /// Shared drawing code for the PNG export and the on-screen SwiftUI view.
    static func draw(scan: RoomScan, in ctx: CGContext, size: CGSize) {
        // Background.
        ctx.setFillColor(UIColor.systemBackground.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        // Bounds over walls + furniture, with a margin.
        var xs: [Double] = [], zs: [Double] = []
        for wall in scan.walls {
            xs += [wall.position.x - wall.size.width / 2, wall.position.x + wall.size.width / 2]
            zs += [wall.position.z - wall.size.depth / 2, wall.position.z + wall.size.depth / 2]
        }
        for item in scan.furniture {
            let r = max(item.size.width, item.size.depth) / 2
            xs += [item.position.x - r, item.position.x + r]
            zs += [item.position.z - r, item.position.z + r]
        }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minZ = zs.min(), let maxZ = zs.max() else { return }
        let spanX = max(maxX - minX, 0.5)
        let spanZ = max(maxZ - minZ, 0.5)
        let pad: CGFloat = 48
        let scale = min((size.width - pad * 2) / spanX, (size.height - pad * 2) / spanZ)
        func point(_ x: Double, _ z: Double) -> CGPoint {
            CGPoint(
                x: pad + CGFloat(x - minX) * scale,
                y: pad + CGFloat(z - minZ) * scale
            )
        }

        // Room outline label.
        let title = "\(scan.name) — \(scan.sizeSummary)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.label,
        ]
        (title as NSString).draw(at: CGPoint(x: pad, y: 12), withAttributes: attrs)

        // Furniture first (under walls, so walls stay readable).
        for item in scan.furniture {
            let w = CGFloat(item.size.width) * scale
            let d = CGFloat(item.size.depth) * scale
            let centre = point(item.position.x, item.position.z)
            ctx.saveGState()
            ctx.translateBy(x: centre.x, y: centre.y)
            ctx.rotate(by: CGFloat(item.rotationDegrees) * .pi / 180)
            let rect = CGRect(x: -w / 2, y: -d / 2, width: w, height: d)
            ctx.setFillColor(UIColor.systemTeal.withAlphaComponent(0.35).cgColor)
            ctx.setStrokeColor(UIColor.systemTeal.cgColor)
            ctx.setLineWidth(2)
            ctx.fill(rect)
            ctx.stroke(rect)
            ctx.restoreGState()

            let label = item.displayName as NSString
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
            ]
            let labelSize = label.size(withAttributes: labelAttrs)
            label.draw(
                at: CGPoint(x: centre.x - labelSize.width / 2, y: centre.y - labelSize.height / 2),
                withAttributes: labelAttrs
            )
        }

        // Walls as thick dark lines (rects, rotated to their yaw).
        for wall in scan.walls {
            let w = CGFloat(max(wall.size.width, wall.size.depth)) * scale
            let thickness = max(CGFloat(0.12) * scale, 6)
            let centre = point(wall.position.x, wall.position.z)
            ctx.saveGState()
            ctx.translateBy(x: centre.x, y: centre.y)
            // A wall's long axis is x when |rotation| is near 0/180, z when near 90/270.
            let yaw = CGFloat(wall.rotationDegrees) * .pi / 180
            ctx.rotate(by: yaw)
            ctx.setFillColor(UIColor.label.cgColor)
            ctx.fill(CGRect(x: -w / 2, y: -thickness / 2, width: w, height: thickness))
            ctx.restoreGState()
        }

        // Doors (green) and windows (blue) as markers on their positions.
        for element in scan.doorsWindows {
            let centre = point(element.position.x, element.position.z)
            let r: CGFloat = 10
            let color: UIColor = element.kind == .door ? .systemGreen : .systemBlue
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
            let label = (element.kind == .door ? "Door" : element.kind == .window ? "Window" : "Opening") as NSString
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: color,
            ]
            label.draw(at: CGPoint(x: centre.x + r + 3, y: centre.y - 8), withAttributes: labelAttrs)
        }
    }
}
