import AppKit

/// Only the slider needs a custom view; the surrounding rows are native menu items.
@MainActor final class VolumeMenuView: NSView {
    private let player: RadioPlayer
    private let slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let quietIcon = NSImageView()
    private let loudIcon = NSImageView()
    var onChange: (() -> Void)?

    init(player: RadioPlayer) {
        self.player = player
        super.init(frame: NSRect(x: 0, y: 0, width: 230, height: 32))
        slider.cell = VolumeSliderCell()
        slider.minValue = 0
        slider.maxValue = 1
        slider.frame = NSRect(x: 48, y: 4, width: bounds.width - 96, height: 24)
        slider.autoresizingMask = [.width]
        slider.isEnabled = true
        slider.isContinuous = true
        slider.controlSize = .regular
        slider.target = self
        slider.action = #selector(changeVolume)
        slider.setAccessibilityLabel("Volym")
        quietIcon.image = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: nil)
        loudIcon.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil)
        for icon in [quietIcon, loudIcon] {
            icon.contentTintColor = .secondaryLabelColor
            icon.imageScaling = .scaleProportionallyDown
            addSubview(icon)
        }
        addSubview(slider)
        needsLayout = true
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        quietIcon.frame = NSRect(x: 20, y: 7, width: 20, height: 18)
        loudIcon.frame = NSRect(x: bounds.width - 40, y: 7, width: 20, height: 18)
        slider.frame = NSRect(x: 48, y: 4, width: max(0, bounds.width - 96), height: 24)
    }

    func fitMenuWidth(_ width: CGFloat) {
        // AppKit does not stretch custom menu-item views to the other rows.
        setFrameSize(NSSize(width: max(230, width - 12), height: 32))
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func refresh() {
        slider.floatValue = player.volume
    }

    @objc private func changeVolume() {
        player.setVolume(slider.floatValue)
        onChange?()
    }
}

/// Menu windows can draw native sliders with inactive tint. Keep the volume
/// track explicitly blue while retaining native knob drawing and interaction.
@MainActor private final class VolumeSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = NSRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6)
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        let fraction = max(0, min(1, (doubleValue - minValue) / (maxValue - minValue)))
        guard fraction > 0 else { return }
        let filled = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: filled, xRadius: 3, yRadius: 3).fill()
    }
    override func drawKnob(_ knobRect: NSRect) {
        let track = barRect(flipped: controlView?.isFlipped ?? false)
        let knob = NSRect(x: knobRect.midX - 9, y: track.midY - 9, width: 18, height: 18)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knob).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

}
