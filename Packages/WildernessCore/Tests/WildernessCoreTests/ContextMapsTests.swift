import Foundation
import Testing
@testable import WildernessCore

private let content = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../../../../App/Content").standardized

private func box(_ minLon: Double, _ minLat: Double, _ maxLon: Double, _ maxLat: Double) -> MapBox {
    MapBox(minLon: minLon, minLat: minLat, maxLon: maxLon, maxLat: maxLat)
}

// MARK: The shipped maps

@Test func theShippedMapsDecodeWithTheirWaterPlacesAndRoute() throws {
    let maps = try ContextMaps.decode(Data(contentsOf: content.appendingPathComponent("maps.json")))
    #expect(Set(maps.maps.map(\.id)) == ["lombardy", "judea", "mediterranean"])
    let lom = try #require(maps.map("lombardy"))
    #expect(lom.places.filter(\.home).map(\.name) == ["Brescia"])
    #expect(lom.lines.contains { $0.name == "Lago di Garda" && $0.closed })
    #expect(maps.map("mediterranean")?.route == ["Brescia", "Jerusalem"])
    #expect(maps.source.lowercased().contains("public domain"))
}

@Test func mapsRejectAPlaceOffTheMapAndARouteToNowhere() {
    let off = #"{"source":"s","maps":[{"id":"m","bbox":{"minLon":0,"minLat":0,"maxLon":1,"maxLat":1},"lines":[],"places":[{"name":"A","lat":5,"lon":0.5,"home":false}],"labels":[],"route":null}]}"#
    #expect(throws: (any Error).self) { try ContextMaps.decode(Data(off.utf8)) }
    let route = #"{"source":"s","maps":[{"id":"m","bbox":{"minLon":0,"minLat":0,"maxLon":1,"maxLat":1},"lines":[],"places":[{"name":"A","lat":0.5,"lon":0.5,"home":true}],"labels":[],"route":["A","B"]}]}"#
    #expect(throws: (any Error).self) { try ContextMaps.decode(Data(route.utf8)) }
}

// MARK: Projection

@Test func projectionFitsTheBoxNorthUpAndKeepsItsShape() {
    // At the equator a degree is a degree both ways: a 2x1 box fits 200x100 exactly.
    let p = MapProjection(box: box(0, 0, 2, 1), width: 200, height: 200)
    #expect(abs(p.width - 200) < 0.01 && abs(p.height - 100) < 0.01)
    let nw = p.point(lon: 0, lat: 1), se = p.point(lon: 2, lat: 0)
    #expect(abs(nw.x) < 1e-9 && abs(nw.y) < 1e-9)
    #expect(abs(se.x - p.width) < 1e-9 && abs(se.y - p.height) < 1e-9)
}

@Test func projectionNarrowsLongitudeAwayFromTheEquator() {
    // At 60° a degree of longitude is half a degree of latitude.
    let p = MapProjection(box: box(0, 59.5, 2, 60.5), width: 1000, height: 1000)
    #expect(abs(p.width / p.height - 1) < 0.01)
}

// MARK: Route

@Test func distanceIsTheGreatCircleDistance() {
    // London to Paris, about 344 km.
    let d = MapProjection.distanceKm(lat1: 51.5074, lon1: -0.1278, lat2: 48.8566, lon2: 2.3522)
    #expect(abs(d - 343.6) < 1.5)
}

@Test func routeFollowsTheGreatCircleAndBowsNorth() {
    let pts = MapProjection.greatCircle(lat1: 45.54, lon1: 10.22, lat2: 31.78, lon2: 35.23, steps: 32)
    #expect(pts.count == 33)
    #expect(abs(pts.first!.lat - 45.54) < 1e-9 && abs(pts.last!.lon - 35.23) < 1e-9)
    let mid = pts[16]
    #expect(mid.lat > (45.54 + 31.78) / 2)
}

// MARK: Pages with a map and a photograph

private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [])
private let maps = ContextMaps(source: "s", maps: [ContextMap(id: "judea", bbox: box(35, 31, 36, 32), lines: [],
                                                                places: [], labels: [], route: nil)])
private func script(_ extra: String) -> Data {
    Data(#"{"pages":[{"id":"a","title":"T","text":"Words.","light":[],"visual":null,"textSide":"left","sources":["Met"],"draft":true\#(extra)}]}"#.utf8)
}

@Test func aPageCanCarryAMapAndACreditedPhotograph() throws {
    let s = try ContextScript.decode(script(#","map":"judea","image":{"file":"judean-desert.jpg","caption":"East of Jerusalem","credit":"Jane Doe, CC BY-SA 4.0"}"#),
                                     library: lib, maps: maps)
    #expect(s.pages[0].map == "judea")
    #expect(s.pages[0].image == ContextImage(file: "judean-desert.jpg", caption: "East of Jerusalem", credit: "Jane Doe, CC BY-SA 4.0"))
    #expect(s.imageCredits == ["Jane Doe, CC BY-SA 4.0"])
}

@Test func aPageRejectsAnUnknownMapOrAnUncreditedPhotograph() {
    #expect(throws: (any Error).self) { try ContextScript.decode(script(#","map":"atlantis""#), library: lib, maps: maps) }
    #expect(throws: (any Error).self) {
        try ContextScript.decode(script(#","image":{"file":"x.jpg","caption":null,"credit":"  "}"#), library: lib, maps: maps)
    }
    #expect(throws: (any Error).self) {
        try ContextScript.decode(script(#","image":{"file":"","caption":null,"credit":"Someone"}"#), library: lib, maps: maps)
    }
}
