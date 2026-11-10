import CoreText
import SwiftUI

/// The app's type (spec §6.1): Cormorant Garamond for titles, EB Garamond for text.
/// Both are SIL Open Font License, bundled in App/Fonts. Sizes are artwork canvas units
/// (20 units ≈ 1 in on the wall).
enum Typography {
    static let titleFace = "CormorantGaramond-Regular"   // named instance of the variable font; default is Light
    static let textFace = "EBGaramond-Regular"
    static let textItalicFace = "EBGaramond-Italic"

    enum Size {
        static let title: CGFloat = 40, short: CGFloat = 22, story: CGFloat = 19, verse: CGFloat = 20, citation: CGFloat = 13
    }

    /// Registers every bundled .ttf for this process. Failures are logged, and SwiftUI falls
    /// back to the system serif, which stays legible.
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        if urls.isEmpty { NSLog("Wilderness: no bundled fonts found") }
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                NSLog("Wilderness: font registration failed for \(url.lastPathComponent): \(String(describing: error?.takeRetainedValue()))")
            }
        }
    }

    static func title(_ size: CGFloat = Size.title) -> Font { .custom(titleFace, fixedSize: size) }
    static func text(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? textItalicFace : textFace, fixedSize: size)
    }
}
