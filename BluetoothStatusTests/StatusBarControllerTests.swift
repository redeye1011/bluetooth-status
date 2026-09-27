import AppKit
import XCTest
@testable import BluetoothStatus

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testEveryGeneratedFamilyLoadsAllFourGlyphs() {
        let status = StatusBarController()
        status.style = .color
        for type in PeripheralType.allCases {
            var rendered: [Data] = []
            for family in [IconFamily.a, .b, .c] {
                XCTAssertNotNil(NSImage(named: NSImage.Name(family.assetName(for: type))))
                status.iconFamily = family
                status.update(PeripheralState(id: "A", name: type.displayName, type: type, state: .connected))
                let item: NSStatusItem
                switch type {
                case .keyboard: item = status.keyboardItem
                case .mouse: item = status.mouseItem
                case .speaker: item = status.speakerItem
                case .headphones: item = status.headphonesItem
                }
                let image = item.button?.image
                XCTAssertTrue(containsGreen(image))
                if let data = image?.tiffRepresentation { rendered.append(data) }
            }
            XCTAssertEqual(Set(rendered).count, 3, "Each \(type) family should have its own artwork")
        }
    }

    func testHeadphonesHaveDistinctArtworkInEveryFamily() {
        let status = StatusBarController()
        for family in IconFamily.allCases {
            status.iconFamily = family
            let speaker = PeripheralState(id: "S", name: "JBL", type: .speaker, state: .connected)
            let headphones = PeripheralState(id: "H", name: "AirPods", type: .headphones, state: .connected)
            if family != .system {
                XCTAssertNotNil(NSImage(named: NSImage.Name(family.assetName(for: .headphones))))
            }
            status.update(speaker)
            let speakerImage = status.speakerItem.button?.image?.tiffRepresentation
            status.update(headphones)
            let headphonesImage = status.headphonesItem.button?.image?.tiffRepresentation
            XCTAssertNotNil(headphonesImage)
            XCTAssertNotEqual(speakerImage, headphonesImage)
            XCTAssertEqual(speakerImage, status.speakerItem.button?.image?.tiffRepresentation)
            XCTAssertTrue(containsGreen(status.headphonesItem.button?.image))
            XCTAssertEqual(status.headphonesItem.button?.accessibilityLabel(), "Headphones: AirPods, Connected")
            status.update(PeripheralState(id: "H", name: "AirPods", type: .headphones, state: .disconnected))
            XCTAssertTrue(containsRed(status.headphonesItem.button?.image))
            status.style = .shape
            status.update(headphones)
            let filled = status.headphonesItem.button?.image?.tiffRepresentation
            status.update(PeripheralState(id: "H", name: "AirPods", type: .headphones, state: .disconnected))
            XCTAssertNotEqual(filled, status.headphonesItem.button?.image?.tiffRepresentation)
            status.style = .color
        }
    }

    func testHiddenItemKeepsStateAndCanBeShownAgain() {
        let status = StatusBarController()
        XCTAssertTrue(status.hasVisibleItems)
        XCTAssertTrue(status.keyboardItem.isVisible)
        XCTAssertTrue(status.mouseItem.isVisible)
        XCTAssertTrue(status.speakerItem.isVisible)
        XCTAssertTrue(status.headphonesItem.isVisible)

        status.setVisible(false, for: .speaker)
        XCTAssertFalse(status.speakerItem.isVisible)
        XCTAssertTrue(status.keyboardItem.isVisible)
        XCTAssertTrue(status.mouseItem.isVisible)
        XCTAssertTrue(status.headphonesItem.isVisible)

        status.update(PeripheralState(id: "S", name: "JBL", type: .speaker, state: .disconnected))
        XCTAssertEqual(status.state(for: .speaker), .disconnected)
        status.setVisible(true, for: .speaker)
        XCTAssertTrue(status.speakerItem.isVisible)
        XCTAssertEqual(status.speakerItem.button?.toolTip, "JBL — Disconnected")
        XCTAssertTrue(containsRed(status.speakerItem.button?.image))

        for type in PeripheralType.allCases { status.setVisible(false, for: type) }
        XCTAssertFalse(status.hasVisibleItems)
    }

    func testConnectedMenusShowBatteryForEveryGlyph() {
        let status = StatusBarController()
        for type in PeripheralType.allCases {
            let item: NSStatusItem
            switch type {
            case .keyboard: item = status.keyboardItem
            case .mouse: item = status.mouseItem
            case .speaker: item = status.speakerItem
            case .headphones: item = status.headphonesItem
            }
            status.update(PeripheralState(id: "A", name: type.displayName, type: type, state: .connected, batteryPercent: 82))
            XCTAssertEqual(item.menu?.items[2].title, "Battery 82%")
            XCTAssertEqual(item.menu?.items[2].isHidden, false)
            XCTAssertEqual(item.menu?.items.prefix(3).map(\.isEnabled), [false, false, false])
            XCTAssertTrue(item.menu?.items.prefix(3).allSatisfy { $0.view != nil } == true)
            XCTAssertEqual(item.menu?.items[4].isEnabled, true)
            let state = item.menu?.items[1].view?.subviews.first as? NSTextField
            let battery = item.menu?.items[2].view?.subviews.first as? NSTextField
            XCTAssertEqual(state?.attributedStringValue.string, "●\u{2002}Connected")
            XCTAssertEqual(state?.attributedStringValue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemGreen)
            XCTAssertEqual(state?.attributedStringValue.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor, .labelColor)
            XCTAssertEqual(battery?.attributedStringValue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .labelColor)
            XCTAssertEqual(item.button?.toolTip, "\(type.displayName) — Connected")
            XCTAssertEqual(item.button?.accessibilityLabel(), "\(type.displayName): \(type.displayName), Connected")

            status.update(PeripheralState(id: "A", name: type.displayName, type: type, state: .connected))
            XCTAssertEqual(item.menu?.items[2].title, "")
            XCTAssertEqual(item.menu?.items[2].isHidden, true)

            status.update(PeripheralState(id: "A", name: type.displayName, type: type, state: .disconnected, batteryPercent: 82))
            XCTAssertEqual(item.button?.toolTip, "\(type.displayName) — Disconnected")
            XCTAssertEqual(item.menu?.items[2].isHidden, true)
        }
    }

    func testIndependentItemsShowSelectedDeviceStates() {
        let status = StatusBarController()
        XCTAssertFalse(status.keyboardItem === status.mouseItem)
        XCTAssertFalse(status.keyboardItem === status.speakerItem)
        XCTAssertFalse(status.speakerItem === status.headphonesItem)

        status.update(PeripheralState(id: "KEYBOARD", name: "Keychron K2", type: .keyboard, state: .connected))
        status.update(PeripheralState(id: "MOUSE", name: "MX Master 3S", type: .mouse, state: .disconnected))
        status.update(PeripheralState(id: "SPEAKER", name: "JBL Boombox 2", type: .speaker, state: .connected))

        XCTAssertTrue(containsGreen(status.keyboardItem.button?.image))
        XCTAssertTrue(containsRed(status.mouseItem.button?.image))
        XCTAssertTrue(containsGreen(status.speakerItem.button?.image))
        XCTAssertEqual(status.keyboardItem.button?.toolTip, "Keychron K2 — Connected")
        XCTAssertEqual(status.mouseItem.button?.toolTip, "MX Master 3S — Disconnected")
        XCTAssertEqual(status.speakerItem.button?.toolTip, "JBL Boombox 2 — Connected")
        status.update(PeripheralState(id: "SPEAKER", name: "JBL Boombox 2", type: .speaker, state: .disconnected))
        XCTAssertTrue(containsRed(status.speakerItem.button?.image))
        XCTAssertEqual(status.mouseItem.menu?.items[0].isEnabled, false)
        XCTAssertEqual(status.mouseItem.menu?.items[1].isEnabled, false)
        XCTAssertEqual(status.mouseItem.menu?.autoenablesItems, false)
        let name = status.mouseItem.menu?.items[0].view?.subviews.first as? NSTextField
        let state = status.mouseItem.menu?.items[1].view?.subviews.first as? NSTextField
        XCTAssertEqual(name?.attributedStringValue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .labelColor)
        XCTAssertEqual(state?.attributedStringValue.string, "●\u{2002}Disconnected")
        XCTAssertEqual(state?.attributedStringValue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemRed)
        XCTAssertEqual(state?.attributedStringValue.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor, .labelColor)
    }

    func testEveryDeviceHasDistinctConnectedAndDisconnectedImagesInEachStyle() {
        let status = StatusBarController()
        for family in IconFamily.allCases {
            status.iconFamily = family
            for type in PeripheralType.allCases {
                let item: NSStatusItem
                switch type {
                case .keyboard: item = status.keyboardItem
                case .mouse: item = status.mouseItem
                case .speaker: item = status.speakerItem
                case .headphones: item = status.headphonesItem
                }
                for style in IndicatorStyle.allCases {
                    status.style = style
                    status.update(PeripheralState(id: "A", name: type.displayName, type: type, state: .connected))
                    let connectedImage = item.button?.image
                    let connected = connectedImage?.tiffRepresentation
                    XCTAssertEqual(connectedImage?.isTemplate, false)
                    if style == .color { XCTAssertTrue(containsGreen(connectedImage)) }

                    status.update(PeripheralState(id: "A", name: type.displayName, type: type, state: .disconnected))
                    let disconnectedImage = item.button?.image
                    let disconnected = disconnectedImage?.tiffRepresentation
                    XCTAssertNotNil(connected)
                    XCTAssertNotEqual(connected, disconnected, "\(type) \(style) \(family) must visibly change with state")
                    if style == .color { XCTAssertTrue(containsRed(disconnectedImage)) }
                }
            }
        }
    }

    func testKeyboardAndMouseColorsCoverAllFourConnectionCombinations() {
        let status = StatusBarController()
        for keyboardConnected in [true, false] {
            for mouseConnected in [true, false] {
                status.update(PeripheralState(
                    id: "K", name: "Keyboard", type: .keyboard,
                    state: keyboardConnected ? .connected : .disconnected
                ))
                status.update(PeripheralState(
                    id: "M", name: "Mouse", type: .mouse,
                    state: mouseConnected ? .connected : .disconnected
                ))
                XCTAssertEqual(containsGreen(status.keyboardItem.button?.image), keyboardConnected)
                XCTAssertEqual(containsRed(status.keyboardItem.button?.image), !keyboardConnected)
                XCTAssertEqual(containsGreen(status.mouseItem.button?.image), mouseConnected)
                XCTAssertEqual(containsRed(status.mouseItem.button?.image), !mouseConnected)
            }
        }
    }

    func testMonochromeSquaresUseWhiteFillAndHollowOutline() {
        for family in IconFamily.allCases {
            for type in PeripheralType.allCases {
                let connected = StatusIcon.image(for: type, state: .connected, style: .monochrome,
                                                 family: family, name: type.displayName)
                let disconnected = StatusIcon.image(for: type, state: .disconnected, style: .monochrome,
                                                    family: family, name: type.displayName)
                XCTAssertGreaterThan(averageBrightness(connected), 0.5)
                XCTAssertLessThan(alpha(atX: 0, y: 0, in: connected), alpha(atX: 10, y: 1, in: connected))
                XCTAssertLessThan(alpha(atX: 0, y: 0, in: disconnected), alpha(atX: 10, y: 1, in: disconnected))
                XCTAssertGreaterThan(opaquePixelCount(connected), 220)
                XCTAssertGreaterThan(opaquePixelCount(connected), opaquePixelCount(disconnected) + 30)
            }
        }
    }

    func testGeneratedOutlineFillUsesBackgroundFreeAssets() {
        for family in [IconFamily.a, .b, .c] {
            for type in PeripheralType.allCases {
                let baseName = family.assetName(for: type)
                for (state, suffix) in [(ConnectionState.connected, "Filled"), (.disconnected, "Outline")] {
                    XCTAssertNotNil(NSImage(named: NSImage.Name(baseName + suffix)))
                    let icon = StatusIcon.image(for: type, state: state, style: .shape,
                                                family: family, name: type.displayName)
                    XCTAssertLessThan(alpha(atX: 2, y: 3, in: icon), 0.1, "\(family) \(type) \(suffix) has no badge")
                }
            }
        }
    }

    private func alpha(atX x: Int, y: Int, in image: NSImage?) -> CGFloat {
        guard let image, let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 20, pixelsHigh: 18,
                                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                       isPlanar: false, colorSpaceName: .deviceRGB,
                                                       bytesPerRow: 0, bitsPerPixel: 0) else { return 0 }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: 20, height: 18))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }

    private func containsGreen(_ image: NSImage?) -> Bool {
        containsPixel(image) { $0.greenComponent > $0.redComponent * 1.3 && $0.greenComponent > $0.blueComponent * 1.2 }
    }

    private func containsRed(_ image: NSImage?) -> Bool {
        containsPixel(image) { $0.redComponent > $0.greenComponent * 1.3 && $0.redComponent > $0.blueComponent * 1.3 }
    }

    private func containsPixel(_ image: NSImage?, matching predicate: (NSColor) -> Bool) -> Bool {
        guard let data = image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return false }
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.5 else { continue }
                if predicate(color) { return true }
            }
        }
        return false
    }

    private func opaquePixelCount(_ image: NSImage?) -> Int {
        guard let data = image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return 0 }
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { count += 1 }
            }
        }
        return count
    }

    private func averageBrightness(_ image: NSImage?) -> Double {
        guard let data = image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return 0 }
        var sum = 0.0
        var count = 0.0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.5 else { continue }
                sum += 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
                count += 1
            }
        }
        return count == 0 ? 0 : sum / count
    }
}
