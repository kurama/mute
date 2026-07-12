import AppKit

extension NSImage {
    func filled(with color: NSColor, size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            self.draw(in: rect)
            color.set()
            rect.fill(using: .sourceIn)
            return true
        }
    }
}
