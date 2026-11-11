import Foundation

/// Real maps for Context (App/Content/maps.json, built by scripts/make_maps.py from Natural
/// Earth, public domain): coastlines, lakes and rivers as lon/lat polylines, plus places.
public struct ContextMaps: Codable, Equatable, Sendable {
    public var source: String
    public var maps: [ContextMap]

    public init(source: String, maps: [ContextMap]) { self.source = source; self.maps = maps }
    public static let empty = ContextMaps(source: "", maps: [])

    public func map(_ id: String) -> ContextMap? { maps.first { $0.id == id } }

    public static func decode(_ data: Data) throws -> ContextMaps {
        typealias Invalid = AnnotationLibrary.ValidationError
        let m = try JSONDecoder().decode(ContextMaps.self, from: data)
        for map in m.maps {
            let b = map.bbox
            guard b.minLon < b.maxLon, b.minLat < b.maxLat else { throw Invalid.invalid("map \(map.id): empty box") }
            guard map.lines.allSatisfy({ $0.points.allSatisfy { $0.count == 2 } }) else {
                throw Invalid.invalid("map \(map.id): every point needs [lon, lat]")
            }
            if let p = map.places.first(where: { !b.contains(lon: $0.lon, lat: $0.lat) }) {
                throw Invalid.invalid("map \(map.id): \(p.name) is off the map")
            }
            let names = Set(map.places.map(\.name))
            if let r = map.route, r.count != 2 || !r.allSatisfy(names.contains) {
                throw Invalid.invalid("map \(map.id): route must join two of its places")
            }
        }
        return m
    }
}

public struct ContextMap: Codable, Equatable, Sendable {
    public var id: String
    public var bbox: MapBox
    public var lines: [MapLine]
    public var places: [MapPlace]
    public var labels: [MapLabel]
    /// Two place names joined by a great-circle arc, or nil.
    public var route: [String]?

    public init(id: String, bbox: MapBox, lines: [MapLine], places: [MapPlace], labels: [MapLabel], route: [String]?) {
        self.id = id; self.bbox = bbox; self.lines = lines; self.places = places; self.labels = labels; self.route = route
    }
}

public struct MapBox: Codable, Equatable, Sendable {
    public var minLon, minLat, maxLon, maxLat: Double
    public init(minLon: Double, minLat: Double, maxLon: Double, maxLat: Double) {
        self.minLon = minLon; self.minLat = minLat; self.maxLon = maxLon; self.maxLat = maxLat
    }
    public func contains(lon: Double, lat: Double) -> Bool {
        (minLon...maxLon).contains(lon) && (minLat...maxLat).contains(lat)
    }
}

public struct MapLine: Codable, Equatable, Sendable {
    /// "coast", "lake" or "river".
    public var kind: String
    public var name: String
    /// A whole lake outline (fill it); otherwise an open line.
    public var closed: Bool
    /// [lon, lat] pairs.
    public var points: [[Double]]
}

public struct MapPlace: Codable, Equatable, Sendable {
    public var name: String
    public var lat: Double
    public var lon: Double
    /// The place the page is about: drawn in gold.
    public var home: Bool
    /// Which side of the point its name goes; nil lets the view choose (right, or left near the edge).
    public var label: LabelSide?
}

public enum LabelSide: String, Codable, Sendable { case left, right, above, below }

public struct MapLabel: Codable, Equatable, Sendable {
    public var text: String
    public var lat: Double
    public var lon: Double
}

/// Equirectangular, scaled by cos(mid-latitude) so shapes look right, north up, fitted inside
/// `width × height` and keeping the box's shape. `width`/`height` are the drawn size.
public struct MapProjection: Sendable {
    public let box: MapBox
    public let width: Double
    public let height: Double
    private let k: Double
    private let scale: Double

    public init(box: MapBox, width: Double, height: Double) {
        self.box = box
        k = cos((box.minLat + box.maxLat) / 2 * .pi / 180)
        let spanX = (box.maxLon - box.minLon) * k, spanY = box.maxLat - box.minLat
        scale = min(width / spanX, height / spanY)
        self.width = spanX * scale
        self.height = spanY * scale
    }

    public func point(lon: Double, lat: Double) -> (x: Double, y: Double) {
        ((lon - box.minLon) * k * scale, (box.maxLat - lat) * scale)
    }

    /// Haversine distance, Earth radius 6371 km.
    public static func distanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = Double.pi / 180
        let a = pow(sin((lat2 - lat1) * r / 2), 2) + cos(lat1 * r) * cos(lat2 * r) * pow(sin((lon2 - lon1) * r / 2), 2)
        return 2 * 6371 * asin(min(1, sqrt(a)))
    }

    /// `steps + 1` points along the great circle (spherical interpolation).
    public static func greatCircle(lat1: Double, lon1: Double, lat2: Double, lon2: Double,
                                   steps: Int) -> [(lat: Double, lon: Double)] {
        let r = Double.pi / 180
        func vec(_ lat: Double, _ lon: Double) -> (Double, Double, Double) {
            (cos(lat * r) * cos(lon * r), cos(lat * r) * sin(lon * r), sin(lat * r))
        }
        let a = vec(lat1, lon1), b = vec(lat2, lon2)
        let omega = acos(min(1, max(-1, a.0 * b.0 + a.1 * b.1 + a.2 * b.2)))
        return (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let (wa, wb) = omega == 0 ? (1 - t, t) : (sin((1 - t) * omega) / sin(omega), sin(t * omega) / sin(omega))
            let x = wa * a.0 + wb * b.0, y = wa * a.1 + wb * b.1, z = wa * a.2 + wb * b.2
            return (atan2(z, sqrt(x * x + y * y)) / r, atan2(y, x) / r)
        }
    }
}
