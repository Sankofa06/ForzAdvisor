#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

struct MarketingScreen {
    let fileName: String
    let headline: String
    let accent: NSColor
    let screenTitle: String
    let rows: [MockRow]
    let actionTitle: String
    let footer: String
}

struct MockRow {
    let title: String
    let detail: String
    let color: NSColor
}

let canvasSize = CGSize(width: 1320, height: 2868)
let outputDirectory = URL(fileURLWithPath: "AppStore/screenshots", isDirectory: true)
let marketingDirectory = URL(fileURLWithPath: "AppStore/marketing", isDirectory: true)

let teal = NSColor(calibratedRed: 0.00, green: 0.72, blue: 0.78, alpha: 1)
let orange = NSColor(calibratedRed: 0.96, green: 0.42, blue: 0.24, alpha: 1)
let gold = NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.22, alpha: 1)
let green = NSColor(calibratedRed: 0.30, green: 0.82, blue: 0.46, alpha: 1)
let violet = NSColor(calibratedRed: 0.50, green: 0.36, blue: 0.92, alpha: 1)
let blue = NSColor(calibratedRed: 0.18, green: 0.56, blue: 0.96, alpha: 1)

let screens: [MarketingScreen] = [
    MarketingScreen(
        fileName: "01-build-a-tune-fast.png",
        headline: "START TUNES\nFASTER",
        accent: teal,
        screenTitle: "Garage",
        rows: [
            MockRow(title: "New Tune", detail: "Photo, screenshot, or manual entry", color: orange),
            MockRow(title: "1997 Skyline GT-R", detail: "Road - S1 900 - saved today", color: teal),
            MockRow(title: "2018 Mustang GT", detail: "Drag - A 800 - adjusted", color: gold),
            MockRow(title: "Search Garage", detail: "Find setups by car or discipline", color: green)
        ],
        actionTitle: "New Tune",
        footer: "Keep every setup searchable in one local garage."
    ),
    MarketingScreen(
        fileName: "02-photo-screenshot-or-manual.png",
        headline: "SCAN,\nIMPORT,\nOR TYPE",
        accent: orange,
        screenTitle: "Tune Source",
        rows: [
            MockRow(title: "Take Photo", detail: "Capture the performance screen", color: orange),
            MockRow(title: "Import Screenshot", detail: "Run on-device Vision OCR", color: teal),
            MockRow(title: "Enter Manually", detail: "Type weight, class, PI, and drivetrain", color: blue),
            MockRow(title: "Capture Guide", detail: "Know which stats matter before tuning", color: green)
        ],
        actionTitle: "Review Values",
        footer: "Start from the input path that fits your workflow."
    ),
    MarketingScreen(
        fileName: "03-confirm-every-stat.png",
        headline: "CONFIRM\nEVERY STAT",
        accent: gold,
        screenTitle: "Manual Entry",
        rows: [
            MockRow(title: "Car", detail: "1997 Nissan Skyline GT-R", color: teal),
            MockRow(title: "Weight", detail: "3,240 lb - 54.0% front", color: orange),
            MockRow(title: "Class / PI", detail: "S1 900", color: gold),
            MockRow(title: "Drivetrain", detail: "AWD", color: blue)
        ],
        actionTitle: "Choose Discipline",
        footer: "Stay in control before the tune is generated."
    ),
    MarketingScreen(
        fileName: "04-tune-for-road-drift-drag.png",
        headline: "PICK THE\nDRIVE STYLE",
        accent: violet,
        screenTitle: "Discipline",
        rows: [
            MockRow(title: "Road", detail: "Balanced grip and rotation", color: teal),
            MockRow(title: "Drift", detail: "Angle, throttle response, and control", color: violet),
            MockRow(title: "Drag", detail: "Launch stability and gearing", color: orange),
            MockRow(title: "Dirt", detail: "Compliance for rough surfaces", color: gold)
        ],
        actionTitle: "Generate Tune",
        footer: "Pick the behavior you want before every build."
    ),
    MarketingScreen(
        fileName: "05-copy-complete-settings.png",
        headline: "COPY\nMENU-ORDER\nSETTINGS",
        accent: blue,
        screenTitle: "Road Tune",
        rows: [
            MockRow(title: "Tires", detail: "F 28.0 PSI - R 27.5 PSI", color: teal),
            MockRow(title: "Alignment", detail: "-1.8 / -1.2 camber - 6.4 caster", color: blue),
            MockRow(title: "Damping", detail: "Bump and rebound in menu order", color: orange),
            MockRow(title: "Copy Full Tune", detail: "Paste the complete setup anywhere", color: green)
        ],
        actionTitle: "Copy Full Tune",
        footer: "Menu-order sections keep setup entry fast."
    ),
    MarketingScreen(
        fileName: "06-refine-after-every-run.png",
        headline: "REFINE\nAFTER EVERY\nRUN",
        accent: green,
        screenTitle: "Saved Tune",
        rows: [
            MockRow(title: "Understeer", detail: "Add front grip and rotation", color: teal),
            MockRow(title: "Oversteer", detail: "Calm rear response", color: orange),
            MockRow(title: "Launch Wheelspin", detail: "Adjust gearing and differential", color: gold),
            MockRow(title: "Save Revision", detail: "Keep the garage history current", color: green)
        ],
        actionTitle: "Save Revision",
        footer: "Tune, test, adjust, and keep moving."
    )
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: marketingDirectory, withIntermediateDirectories: true)

for screen in screens {
    let image = try renderMarketingScreen(screen)
    let destination = outputDirectory.appendingPathComponent(screen.fileName)
    try writePNG(image, to: destination)
}

let readme = """
# ForzAdvisor Marketing Screenshots

Generated by `scripts/generate_marketing_screenshots.swift`.

The App Store upload set is written to `AppStore/screenshots/` at 1320 x 2868 pixels. The set uses neutral device mockups, tight workflow headlines, representative ForzAdvisor UI content, and safe sample data without official game branding.

## Upload Order

1. Start Tunes Faster
2. Scan, Import, or Type
3. Confirm Every Stat
4. Pick the Drive Style
5. Copy Menu-Order Settings
6. Refine After Every Run
"""
try readme.write(to: marketingDirectory.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

func drawMarketingScreen(_ screen: MarketingScreen) {
    let rect = CGRect(origin: .zero, size: canvasSize)
    NSColor(calibratedRed: 0.015, green: 0.018, blue: 0.020, alpha: 1).setFill()
    rect.fill()

    drawRacingBackdrop(accent: screen.accent)

    drawWrappedText(
        screen.headline,
        in: CGRect(x: 86, y: 2286, width: 1148, height: 360),
        font: NSFont.systemFont(ofSize: 88, weight: .black),
        color: .white,
        alignment: .center,
        lineHeight: 1.05
    )

    drawPhone(screen)

    drawWrappedText(
        screen.footer,
        in: CGRect(x: 128, y: 112, width: 1064, height: 130),
        font: NSFont.systemFont(ofSize: 38, weight: .semibold),
        color: NSColor.white.withAlphaComponent(0.84),
        alignment: .center,
        lineHeight: 1.18
    )
}

func drawRacingBackdrop(accent: NSColor) {
    drawSlantedPanel(
        points: [
            CGPoint(x: -120, y: 2080),
            CGPoint(x: 1440, y: 1840),
            CGPoint(x: 1440, y: 1600),
            CGPoint(x: -120, y: 1810)
        ],
        color: accent.withAlphaComponent(0.18)
    )

    drawSlantedPanel(
        points: [
            CGPoint(x: -160, y: 620),
            CGPoint(x: 1460, y: 850),
            CGPoint(x: 1460, y: 430),
            CGPoint(x: -160, y: 210)
        ],
        color: NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.11, alpha: 0.92)
    )

    drawSlantedPanel(
        points: [
            CGPoint(x: -100, y: 570),
            CGPoint(x: 1440, y: 790),
            CGPoint(x: 1440, y: 742),
            CGPoint(x: -100, y: 520)
        ],
        color: accent.withAlphaComponent(0.58)
    )

    for index in 0..<8 {
        let x = CGFloat(index) * 182 - 110
        let line = NSBezierPath()
        line.move(to: CGPoint(x: x, y: 0))
        line.line(to: CGPoint(x: x + 520, y: canvasSize.height))
        line.lineWidth = 1
        NSColor.white.withAlphaComponent(index.isMultiple(of: 2) ? 0.045 : 0.025).setStroke()
        line.stroke()
    }
}

func drawSlantedPanel(points: [CGPoint], color: NSColor) {
    guard let first = points.first else { return }
    let path = NSBezierPath()
    path.move(to: first)
    for point in points.dropFirst() {
        path.line(to: point)
    }
    path.close()
    color.setFill()
    path.fill()
}

func drawPhone(_ screen: MarketingScreen) {
    let phone = CGRect(x: 284, y: 560, width: 752, height: 1530)
    let shadow = NSBezierPath(roundedRect: phone.offsetBy(dx: 0, dy: -26), xRadius: 82, yRadius: 82)
    NSColor.black.withAlphaComponent(0.42).setFill()
    shadow.fill()

    let outer = NSBezierPath(roundedRect: phone, xRadius: 78, yRadius: 78)
    NSColor(calibratedRed: 0.02, green: 0.022, blue: 0.025, alpha: 1).setFill()
    outer.fill()
    NSColor.white.withAlphaComponent(0.22).setStroke()
    outer.lineWidth = 5
    outer.stroke()

    let screenRect = phone.insetBy(dx: 38, dy: 42)
    let inner = NSBezierPath(roundedRect: screenRect, xRadius: 52, yRadius: 52)
    NSColor(calibratedRed: 0.075, green: 0.078, blue: 0.086, alpha: 1).setFill()
    inner.fill()

    let notch = NSBezierPath(roundedRect: CGRect(x: phone.midX - 92, y: phone.maxY - 72, width: 184, height: 28), xRadius: 14, yRadius: 14)
    NSColor.black.withAlphaComponent(0.9).setFill()
    notch.fill()

    drawPhoneChrome(in: screenRect, title: screen.screenTitle, accent: screen.accent)
    drawMockRows(screen.rows, in: screenRect, accent: screen.accent, actionTitle: screen.actionTitle)
}

func drawPhoneChrome(in rect: CGRect, title: String, accent: NSColor) {
    drawText("10:26", at: CGPoint(x: rect.minX + 44, y: rect.maxY - 73), font: NSFont.systemFont(ofSize: 21, weight: .semibold), color: .white)
    drawText("ForzAdvisor", at: CGPoint(x: rect.midX - 66, y: rect.maxY - 73), font: NSFont.systemFont(ofSize: 22, weight: .bold), color: .white)

    let menu = NSBezierPath(roundedRect: CGRect(x: rect.minX + 36, y: rect.maxY - 138, width: 58, height: 58), xRadius: 29, yRadius: 29)
    NSColor.white.withAlphaComponent(0.07).setFill()
    menu.fill()
    accent.setStroke()
    let line1 = NSBezierPath()
    line1.move(to: CGPoint(x: rect.minX + 53, y: rect.maxY - 104))
    line1.line(to: CGPoint(x: rect.minX + 77, y: rect.maxY - 104))
    line1.lineWidth = 4
    line1.stroke()
    let line2 = NSBezierPath()
    line2.move(to: CGPoint(x: rect.minX + 53, y: rect.maxY - 119))
    line2.line(to: CGPoint(x: rect.minX + 77, y: rect.maxY - 119))
    line2.lineWidth = 4
    line2.stroke()

    drawText(title, at: CGPoint(x: rect.minX + 42, y: rect.maxY - 224), font: NSFont.systemFont(ofSize: 42, weight: .heavy), color: .white)
}

func drawMockRows(_ rows: [MockRow], in rect: CGRect, accent: NSColor, actionTitle: String) {
    var y = rect.maxY - 380
    for (index, row) in rows.enumerated() {
        let rowRect = CGRect(x: rect.minX + 42, y: y, width: rect.width - 84, height: index == 0 ? 156 : 142)
        let path = NSBezierPath(roundedRect: rowRect, xRadius: 18, yRadius: 18)
        (index == 0 ? row.color.withAlphaComponent(0.88) : NSColor.white.withAlphaComponent(0.07)).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 2
        path.stroke()

        let badge = NSBezierPath(roundedRect: CGRect(x: rowRect.minX + 24, y: rowRect.midY - 28, width: 56, height: 56), xRadius: 18, yRadius: 18)
        row.color.withAlphaComponent(index == 0 ? 1.0 : 0.86).setFill()
        badge.fill()
        drawText(String(index + 1), at: CGPoint(x: rowRect.minX + 43, y: rowRect.midY - 11), font: NSFont.systemFont(ofSize: 22, weight: .black), color: .white)

        drawText(row.title, at: CGPoint(x: rowRect.minX + 104, y: rowRect.maxY - 58), font: NSFont.systemFont(ofSize: 28, weight: .bold), color: .white)
        drawWrappedText(
            row.detail,
            in: CGRect(x: rowRect.minX + 104, y: rowRect.minY + 25, width: rowRect.width - 140, height: 58),
            font: NSFont.systemFont(ofSize: 21, weight: .medium),
            color: NSColor.white.withAlphaComponent(index == 0 ? 0.94 : 0.68),
            alignment: .left,
            lineHeight: 1.12
        )

        y -= rowRect.height + 28
    }

    let action = CGRect(x: rect.minX + 42, y: rect.minY + 92, width: rect.width - 84, height: 92)
    let actionPath = NSBezierPath(roundedRect: action, xRadius: 22, yRadius: 22)
    accent.setFill()
    actionPath.fill()
    drawWrappedText(actionTitle, in: action.insetBy(dx: 16, dy: 24), font: NSFont.systemFont(ofSize: 30, weight: .black), color: .white, alignment: .center, lineHeight: 1)
}

func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    text.draw(at: point, withAttributes: attributes)
}

func drawWrappedText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment, lineHeight: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.minimumLineHeight = font.pointSize * lineHeight
    paragraph.maximumLineHeight = font.pointSize * lineHeight
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    NSString(string: text).draw(in: rect, withAttributes: attributes)
}

func renderMarketingScreen(_ screen: MarketingScreen) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "ForzAdvisorMarketing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap"])
    }
    bitmap.size = canvasSize

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "ForzAdvisorMarketing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.setShouldAntialias(true)
    drawMarketingScreen(screen)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ForzAdvisorMarketing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}
