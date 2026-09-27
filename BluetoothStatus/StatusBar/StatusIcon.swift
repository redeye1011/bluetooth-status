import AppKit

enum StatusIcon {
    static func image(for type: PeripheralType, state: ConnectionState, style: IndicatorStyle, family: IconFamily, name: String, audioKind: AudioKind = .speaker) -> NSImage? {
        let symbol: NSImage
        if family == .system {
            let symbolName: String
            switch type {
            case .keyboard: symbolName = state == .connected ? "keyboard.fill" : "keyboard"
            case .mouse: symbolName = state == .connected ? "computermouse.fill" : "computermouse"
            case .speaker:
                symbolName = audioKind == .headphones ? "earbuds" : (state == .connected ? "speaker.wave.2.fill" : "speaker.slash")
            }
            guard let systemSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: name)?
                .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) else { return nil }
            symbol = systemSymbol
        } else {
            let baseName = family.assetName(for: type, audioKind: audioKind)
            let suffix = style == .shape && state != .unavailable ? (state == .connected ? "Filled" : "Outline") : ""
            guard let generated = NSImage(named: NSImage.Name(baseName + suffix)) else { return nil }
            symbol = generated
        }

        let size = NSSize(width: 20, height: 18)
        let iconColor: NSColor
        switch style {
        case .shape:
            iconColor = state == .unavailable ? .systemGray : .labelColor
        case .monochrome:
            iconColor = state == .unavailable ? .systemGray : (state == .connected ? .black : .white)
        case .color:
            switch state {
            case .connected: iconColor = .systemGreen
            case .disconnected: iconColor = .systemRed
            case .unavailable: iconColor = .systemGray
            }
        }

        let glyph = NSImage(size: size, flipped: false) { rect in
            let maxWidth: CGFloat = style == .monochrome ? 14 : (style == .shape ? 18 : 17)
            let maxHeight: CGFloat = style == .monochrome ? 12 : (style == .shape ? 16 : 15)
            let scale = min(maxWidth / symbol.size.width, maxHeight / symbol.size.height)
            let width = symbol.size.width * scale
            let height = symbol.size.height * scale
            let symbolRect = NSRect(x: (rect.width - width) / 2, y: (rect.height - height) / 2, width: width, height: height)
            symbol.draw(in: symbolRect)
            if family == .system && type == .speaker && audioKind == .headphones && style == .shape {
                symbol.draw(in: symbolRect)
            }
            iconColor.setFill()
            rect.fill(using: .sourceAtop)
            if family == .system && type == .speaker && audioKind == .headphones && style == .shape && state == .disconnected {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 3, y: 3))
                slash.line(to: NSPoint(x: 17, y: 15))
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .clear
                slash.lineWidth = 3
                slash.stroke()
                NSGraphicsContext.restoreGraphicsState()
                NSColor.labelColor.setStroke()
                slash.lineWidth = 1.5
                slash.stroke()
            }
            return true
        }
        glyph.isTemplate = false

        guard style == .monochrome, state != .unavailable else { return glyph }
        let badge = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            (state == .connected ? NSColor.white : NSColor.black).setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
            glyph.draw(in: rect)
            return true
        }
        badge.isTemplate = false
        return badge
    }
}
