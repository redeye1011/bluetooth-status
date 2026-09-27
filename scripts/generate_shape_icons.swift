import AppKit
import CoreGraphics
import Foundation

// Run from the repository root: swift scripts/generate_shape_icons.swift
let catalog = URL(fileURLWithPath: "BluetoothStatus/Assets.xcassets", isDirectory: true)
let outputSize = 256

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func ellipse(_ rect: CGRect) -> CGPath {
    CGPath(ellipseIn: rect, transform: nil)
}

func render(family: String, device: String, filled: Bool) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: outputSize, height: outputSize,
                            bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: 4, y: 4)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.setLineWidth(family == "B" ? 2.8 : 3.5)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    func body(_ path: CGPath) {
        if filled { context.addPath(path); context.fillPath() }
        else { context.addPath(path); context.strokePath() }
    }
    func detail(_ path: CGPath) {
        context.saveGState()
        context.setBlendMode(filled ? .clear : .normal)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }
    func line(_ points: [CGPoint]) {
        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() { context.addLine(to: point) }
        if filled { context.setBlendMode(.clear) }
        context.strokePath()
        context.setBlendMode(.normal)
    }

    switch device {
    case "Keyboard":
        let radius: CGFloat = family == "A" ? 3 : family == "B" ? 5 : 9
        body(rounded(CGRect(x: 3, y: 19, width: 58, height: 27), radius))
        for row in 0..<2 {
            for column in 0..<6 {
                let key = CGRect(x: 9 + column * 8, y: 35 - row * 8, width: 5, height: 4)
                detail(rounded(key, family == "C" ? 2 : 1))
            }
        }
        detail(rounded(CGRect(x: 17, y: 22, width: 30, height: 4), 2))
    case "Mouse":
        let width: CGFloat = family == "B" ? 28 : 32
        let x = (64 - width) / 2
        body(rounded(CGRect(x: x, y: 6, width: width, height: 52),
                     family == "A" ? 13 : width / 2))
        if filled {
            line([CGPoint(x: 32, y: 56), CGPoint(x: 32, y: 40)])
            detail(rounded(CGRect(x: 30, y: 43, width: 4, height: 7), 2))
        } else {
            line([CGPoint(x: x + 2, y: 39), CGPoint(x: x + width - 2, y: 39)])
            line([CGPoint(x: 32, y: 56), CGPoint(x: 32, y: 43)])
        }
    case "Speaker":
        let radius: CGFloat = family == "A" ? 3 : family == "B" ? 6 : 11
        let box = CGRect(x: family == "B" ? 16 : 13, y: 7,
                         width: family == "B" ? 32 : 38, height: 50)
        body(rounded(box, radius))
        let small = ellipse(CGRect(x: 27, y: 42, width: 10, height: 10))
        let large = ellipse(CGRect(x: 22, y: 16, width: 20, height: 20))
        if filled {
            detail(small)
            detail(large)
        } else {
            context.addPath(small); context.strokePath()
            context.addPath(large); context.strokePath()
        }
    case "Headphones":
        for x in [8.0, 36.0] {
            let head = ellipse(CGRect(x: x, y: 33, width: 20, height: 22))
            let stem = rounded(CGRect(x: x + 7, y: 8, width: 7, height: 29),
                               family == "A" ? 1.5 : 3.5)
            body(head)
            body(stem)
            if filled {
                detail(ellipse(CGRect(x: x + 6, y: 41, width: 8, height: 7)))
            } else {
                context.addPath(ellipse(CGRect(x: x + 6, y: 41, width: 8, height: 7)))
                context.strokePath()
            }
        }
    default:
        fatalError("Unknown device")
    }
    return NSBitmapImageRep(cgImage: context.makeImage()!)
        .representation(using: .png, properties: [:])!
}

for family in ["A", "B", "C"] {
    for device in ["Keyboard", "Mouse", "Speaker", "Headphones"] {
        for filled in [true, false] {
            let name = "Menu\(family)\(device)\(filled ? "Filled" : "Outline")"
            let folder = catalog.appendingPathComponent("\(name).imageset", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try render(family: family, device: device, filled: filled)
                .write(to: folder.appendingPathComponent("\(name).png"))
            let contents = """
            {"images":[{"filename":"\(name).png","idiom":"universal"}],"info":{"author":"xcode","version":1}}
            """
            try contents.write(to: folder.appendingPathComponent("Contents.json"),
                               atomically: true, encoding: .utf8)
        }
    }
}
