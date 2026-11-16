import SwiftUI
import UIKit

/// The Siri Remote's Select button, clicked or held for a second, read from the button press
/// alone with UIKit recognizers on the window.
///
/// SwiftUI's gestures read the clickpad's touches too: a thumb resting on a real remote makes
/// small movements that cancel them. That broke hold-Select first, then (Matt, 2026-11-15)
/// single clicks: the first click often did nothing and he had to click again. Both now ignore
/// touches. A click fires on release, only when the press was not a hold.
struct SelectPressDetector: UIViewRepresentable {
    var minimumHold: TimeInterval = 1.0
    let onClick: () -> Void
    let onHold: () -> Void

    func makeUIView(context: Context) -> HostView {
        let v = HostView()
        v.hold.minimumPressDuration = minimumHold
        update(v)
        return v
    }

    func updateUIView(_ view: HostView, context: Context) { update(view) }

    private func update(_ v: HostView) { v.onClick = onClick; v.onHold = onHold }

    final class HostView: UIView {
        let hold = UILongPressGestureRecognizer()
        let click = UITapGestureRecognizer()
        var onClick: (() -> Void)?
        var onHold: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            let select = [NSNumber(value: UIPress.PressType.select.rawValue)]
            for r in [hold, click] as [UIGestureRecognizer] {
                r.allowedPressTypes = select
                r.allowedTouchTypes = []          // presses only: thumb movement can't cancel them
            }
            click.require(toFail: hold)           // a hold is never also a click
            hold.addTarget(self, action: #selector(held(_:)))
            click.addTarget(self, action: #selector(clicked(_:)))
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            for r in [hold, click] as [UIGestureRecognizer] {
                r.view?.removeGestureRecognizer(r)
                window?.addGestureRecognizer(r)   // the window sees every press in the app
            }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil { for r in [hold, click] as [UIGestureRecognizer] { r.view?.removeGestureRecognizer(r) } }
        }

        @objc private func held(_ r: UILongPressGestureRecognizer) { if r.state == .began { onHold?() } }
        @objc private func clicked(_ r: UITapGestureRecognizer) { if r.state == .ended { onClick?() } }
    }
}
