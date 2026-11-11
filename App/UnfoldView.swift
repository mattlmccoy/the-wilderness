import SwiftUI
import WildernessCore

/// The guided arc's text (spec §5.3) in artwork canvas units. The root LightLayer steps
/// through each beat's targets (`targets`); the text appears once the light has settled.
struct UnfoldView: View {
    let script: UnfoldScript
    let playback: UnfoldPlayback
    let library: AnnotationLibrary
    let calibration: Calibration
    var header: String? = nil
    var showsHint: Bool = false

    private var beat: UnfoldBeat { script.beats[playback.beat] }

    /// What the root LightLayer lights for this moment of Unfold.
    static func targets(_ script: UnfoldScript, _ p: UnfoldPlayback) -> Set<String> {
        script.targets(p)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WallText(title: beat.title, short: beat.short, more: beat.more, fallbackExtended: nil,
                     expanded: beat.more != nil,
                     placement: TextColumnLayout.place(preferred: beat.textSide, calibration: calibration),
                     anchorY: anchorY, paused: playback.paused, header: header,
                     hint: showsHint ? Wayfinding.unfoldHint : nil)
            .id(beat.id)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeIn(duration: LightTiming.textIn).delay(LightTiming.textDelay)),
                removal: .opacity.animation(.easeOut(duration: LightTiming.textOut))))
        }
        .animation(.easeInOut(duration: LightTiming.textOut), value: playback.paused)
    }

    /// The first lit subject's height, or upper third for whole-piece beats.
    private var anchorY: Double {
        let ids = beat.light.joined()
        return library.annotations.first { ids.contains($0.id) }?.anchor.y ?? 0.3
    }
}
