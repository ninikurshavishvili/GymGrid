// Draws GymGrid's app icon: a small year grid filling up in green.
//
// Run from gym_grid/, then make Android's sizes from it:
//
//     swift tool/app_icon/generate.swift
//     dart run flutter_launcher_icons
//
// Writes four PNGs:
// - The iOS icon, 1024x1024, straight into the asset catalog. It's a
//   single-size icon, so Xcode makes every other size at build time. App
//   Store Connect rejects an icon with an alpha channel, so it's drawn
//   without one.
// - assets/app_icon/icon.png, the same image, for older Android launchers.
// - assets/app_icon/icon_foreground.png, transparent, for Android's adaptive
//   icon, with the grid shrunk to fit the circle every launcher mask keeps.
// - docs/images/app-icon.png, 512x512 with rounded corners, for the README.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The app's own colours, from AppColors.dark.
let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
let gridEmpty = CGColor(srgbRed: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255, alpha: 1)
let gridFilled = CGColor(srgbRed: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255, alpha: 1)

/// Which squares are green, top row first: a staircase, like a habit
/// building up week by week.
let pattern: [[Bool]] = [
    [false, false, false, true],
    [false, false, true, true],
    [false, true, true, true],
    [true, true, true, true],
]

/// The gap between squares, and their corner radius, as fractions of a
/// square's side. The radius matches the grid on the home screen.
let gapRatio = 0.28
let cornerRatio = 0.22

/// How a finished icon looks, before it's written out.
enum Background {
    /// Black to the edges, with no alpha channel.
    case opaque
    /// Nothing behind the grid, for Android to fill in.
    case transparent
    /// Black inside an iOS-style rounded square, transparent outside it.
    case rounded
}

func drawGrid(in context: CGContext, canvas: Double, side: Double) {
    let count = Double(pattern.count)
    let cell = side / (count + (count - 1) * gapRatio)
    let gap = cell * gapRatio
    let origin = (canvas - side) / 2

    for (row, squares) in pattern.enumerated() {
        for (column, isFilled) in squares.enumerated() {
            // Core Graphics counts y from the bottom, and row 0 is the top.
            let rect = CGRect(
                x: origin + Double(column) * (cell + gap),
                y: origin + (count - 1 - Double(row)) * (cell + gap),
                width: cell,
                height: cell
            )
            let radius = cell * cornerRatio
            context.addPath(
                CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            )
            context.setFillColor(isFilled ? gridFilled : gridEmpty)
            context.fillPath()
        }
    }
}

/// Draws the icon at [size] pixels square, with the grid taking up
/// [gridFraction] of the width, and writes it to [path].
func write(to path: String, size: Int, background: Background, gridFraction: Double) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGImageAlphaInfo = background == .opaque ? .noneSkipLast : .premultipliedLast
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: alpha.rawValue
    )!
    let canvas = Double(size)
    let bounds = CGRect(x: 0, y: 0, width: canvas, height: canvas)

    switch background {
    case .opaque:
        context.setFillColor(black)
        context.fill(bounds)
    case .transparent:
        break
    case .rounded:
        // About the corner radius iOS gives a home screen icon.
        let radius = canvas * 0.2237
        context.addPath(CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.setFillColor(black)
        context.fillPath()
    }
    drawGrid(in: context, canvas: canvas, side: canvas * gridFraction)

    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(path)") }
    print("Wrote \(path)")
}

// iOS rounds the corners off, so the grid keeps well inside them.
let gridFraction = 0.625
write(
    to: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
    size: 1024, background: .opaque, gridFraction: gridFraction
)
write(to: "assets/app_icon/icon.png", size: 1024, background: .opaque, gridFraction: gridFraction)
// Android keeps only a circle 66/108 of the icon wide, and the grid's
// corners have to fit inside it.
write(
    to: "assets/app_icon/icon_foreground.png",
    size: 1024, background: .transparent, gridFraction: 440.0 / 1024
)
write(to: "docs/images/app-icon.png", size: 512, background: .rounded, gridFraction: gridFraction)
