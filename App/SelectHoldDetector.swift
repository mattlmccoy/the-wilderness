import SwiftUI
import UIKit

/// Detects the Siri Remote's Select button being held for a second, using a UIKit press
/// recognizer on the window. SwiftUI's onLongPressGesture worked with the simulated remote but
/// not for Matt's real one: a thumb resting on the clickpad also makes small touch movements,
/// which cancel a touch-based long press. This listens to the button press only.
struct SelectHoldDetector: UIViewRepresentable {
    var minimumDuration: TimeInterval = 1.0
    let onHold: () -> Void

    func makeUIView(context: Context) -> HostView {
        let v = HostView()
        v.recognizer.minimumPressDuration = minimumDuration
        v.onHold = onHold
        return v
    }

    func updateUIView(_ view: HostView, context: Context) { view.onHold = onHold }

    final class HostView: UIView {
        let recognizer = UILongPressGestureRecognizer()
        var onHold: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            recognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
            recognizer.allowedTouchTypes = []          // presses only: thumb movement can't cancel it
            recognizer.addTarget(self, action: #selector(fired(_:)))
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            window?.addGestureRecognizer(recognizer)   // the window sees every press in the app
        }

        @objc private func fired(_ r: UILongPressGestureRecognizer) {
            if r.state == .began { onHold?() }
        }
    }
}
