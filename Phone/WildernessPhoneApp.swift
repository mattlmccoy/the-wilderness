import CoreText
import os
import SwiftUI
import WildernessCore

@main
struct WildernessPhoneApp: App {
    private let library: AnnotationLibrary?

    init() {
        PhoneType.registerFonts()
        library = Self.loadLibrary()
    }

    var body: some Scene {
        WindowGroup { PhoneRootView(library: library).preferredColorScheme(.dark) }
    }

    /// Outlines and ids only; no licensed text is bundled on the phone (it comes from the Apple TV).
    private static func loadLibrary() -> AnnotationLibrary? {
        let log = Logger(subsystem: "com.mattmccoy.wilderness.phone", category: "content")
        guard let url = Bundle.main.url(forResource: "annotations", withExtension: "json") else {
            log.error("annotations.json missing from the phone bundle")
            return nil
        }
        do { return try AnnotationLibrary.decode(Data(contentsOf: url)) } catch {
            log.error("annotations.json invalid: \(String(describing: error))")
            return nil
        }
    }
}

enum PhonePalette {
    static let ivory = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let gold = Color(red: 0.72, green: 0.61, blue: 0.37)
    static let stone = Color(red: 0.60, green: 0.56, blue: 0.50)
}

/// The wall's type on the phone: Cormorant Garamond titles, EB Garamond text (bundled, OFL).
enum PhoneType {
    static func title(_ size: CGFloat) -> Font { .custom("CormorantGaramond-Regular", size: size) }
    static func text(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "EBGaramond-Italic" : "EBGaramond-Regular", size: size)
    }

    static func registerFonts() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
