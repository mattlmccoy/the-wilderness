import SwiftUI

/// Colours drawn from the painting. Everything else in the projection is black,
/// because black is the only colour that adds (almost) no light to the tapestry.
enum Palette {
    static let ivory = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let gold = Color(red: 0.72, green: 0.61, blue: 0.37)
    static let stone = Color(red: 0.60, green: 0.56, blue: 0.50)
}

/// Shape of the woven image itself. 60 in wide × 50 in tall.
enum Artwork {
    static let aspect = 60.0 / 50.0
    /// Design-unit size of the canvas the artwork layer is drawn in (1 unit ≈ 0.05 in on the wall).
    static let canvasWidth = 1200.0
    static var canvasHeight: Double { canvasWidth / aspect }
}
