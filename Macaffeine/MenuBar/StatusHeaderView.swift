import AppKit

final class StatusHeaderView: NSView {
    private let dot = StatusDotView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 46))
        autoresizingMask = [.width]

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        detailLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detailLabel.textColor = .secondaryLabelColor

        for view in [dot, titleLabel, detailLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            dot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 14),
            dot.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with status: MenuStatus) {
        dot.tone = status.tone
        titleLabel.stringValue = status.title
        detailLabel.stringValue = status.detail
        setAccessibilityLabel("\(status.title). \(status.detail)")

        let width = max(frame.width, fittingSize.width)
        setFrameSize(NSSize(width: width, height: fittingSize.height))
    }
}

private final class StatusDotView: NSView {
    var tone = MenuStatus.Tone.idle {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = switch tone {
        case .active: .systemGreen
        case .idle: .tertiaryLabelColor
        case .warning: .systemOrange
        case .error: .systemRed
        }

        if tone != .idle {
            color.withAlphaComponent(0.25).setFill()
            NSBezierPath(ovalIn: bounds).fill()
        }
        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3)).fill()
    }
}
