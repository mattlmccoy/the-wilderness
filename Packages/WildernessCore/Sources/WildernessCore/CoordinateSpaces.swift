/// Coordinate spaces are phantom types so points and transforms from different
/// spaces cannot be mixed by accident. Every space here is *normalized*:
/// the visible tapestry, the projector frame and the camera image each span 0...1
/// on both axes, with the origin at the top left and y pointing down.
/// Pixel sizes are applied only at the render edge (see `Homography.scaled`).
public protocol CoordinateSpace {}

/// The tapestry itself: (0,0) top-left corner of the woven image, (1,1) bottom-right.
/// Annotation geometry is authored in this space.
public enum ArtworkSpace: CoordinateSpace {}

/// The full projector / Apple TV output frame: (0,0) top-left pixel, (1,1) bottom-right.
public enum ProjectorSpace: CoordinateSpace {}

/// An iPhone calibration photo (used only by camera-assisted calibration).
public enum CameraSpace: CoordinateSpace {}

/// Un-normalized points of the SwiftUI canvas the artwork layer is drawn in.
public enum CanvasSpace: CoordinateSpace {}

/// Un-normalized points of the full-screen tvOS view (the render edge).
public enum ScreenSpace: CoordinateSpace {}

public struct Point<Space: CoordinateSpace>: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
