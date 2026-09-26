import AppKit

enum StatusIcon {
    static func image(for type: PeripheralType, state: ConnectionState, style: IndicatorStyle, family: IconFamily, name: String) -> NSImage? {
        let symbol: NSImage
        if family == .system {
            let symbolName: String
            switch type {
            case .keyboard: symbolName = state == .connected ? "keyboard.fill" : "keyboard"
            case .mouse: symbolName = state == .connected ? "computermouse.fill" : "computermouse"
            case .speaker: symbolName = state == .connected ? "speaker.wave.2.fill" : "speaker.slash"
            }
            guard let systemSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: name)?
                .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) else { return nil }
            symbol = systemSymbol
        } else {
            guard let generated = NSImage(named: NSImage.Name(family.assetName(for: type))) else { return nil }
            symbol = generated
        }

        let size = NSSize(width: 20, height: 18)
        let shapeBadge = style == .shape && family != .system && state != .unavailable
        let iconColor: NSColor
        switch style {
        case .shape:
            iconColor = state == .unavailable ? .systemGray : (shapeBadge && state == .connected ? .windowBackgroundColor : .labelColor)
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
            let scale = min((shapeBadge ? 13 : 17) / symbol.size.width, (shapeBadge ? 11 : 15) / symbol.size.height)
            let width = symbol.size.width * scale
            let height = symbol.size.height * scale
            symbol.draw(in: NSRect(x: (rect.width - width) / 2, y: (rect.height - height) / 2, width: width, height: height))
            iconColor.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        glyph.isTemplate = false

        if shapeBadge {
            let badge = NSImage(size: size, flipped: false) { rect in
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
                if state == .connected {
                    NSColor.labelColor.setFill()
                    path.fill()
                } else {
                    NSColor.labelColor.setStroke()
                    path.lineWidth = 1.5
                    path.stroke()
                }
                glyph.draw(in: rect)
                return true
            }
            badge.isTemplate = false
            return badge
        }

        guard style == .monochrome, state != .unavailable else { return glyph }
        let badge = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
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
