import Foundation
import Testing
@testable import WildernessCore

/// Validates the actual content file the app ships, not a fixture.
private let contentURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("App/Content/annotations.json")

@Test func shippedContentDecodesAndValidates() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    #expect(lib.annotations.count >= 3)
    #expect(abs(lib.artworkAspect - 60.0 / 50.0) < 1e-9)
}

@Test func everyShippedDetailIsReachableByTheRemote() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let dirs: [NudgeDirection] = [.left, .right, .up, .down]
    // Breadth-first walk from the first detail using only remote presses.
    var seen: Set<String> = [lib.annotations[0].id], queue = [lib.annotations[0]]
    while let cur = queue.popLast() {
        for d in dirs {
            if let n = SpatialNavigator.next(from: cur, direction: d, among: lib.annotations, artworkAspect: lib.artworkAspect),
               seen.insert(n.id).inserted { queue.append(n) }
        }
    }
    #expect(seen.count == lib.annotations.count, "unreachable: \(Set(lib.annotations.map(\.id)).subtracting(seen))")
}

@Test func everyShippedSubjectHasAnOutline() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    for a in lib.annotations {
        #expect((a.outline?.count ?? 0) >= 6, "\(a.id) has no usable outline")
    }
}

@Test func shippedShortLinesRespectTheWordLimit() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    for a in lib.annotations {
        #expect(WordLimits.count(a.short) <= WordLimits.short, "\(a.id): \(WordLimits.count(a.short)) words")
    }
}

@Test func shippedMoreRespectsWordLimits() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    for a in lib.annotations {
        guard let m = a.more, !m.draft else { continue }
        #expect(WordLimits.count(m.story) <= WordLimits.story, "\(a.id) story")
        for v in m.verses { #expect(WordLimits.count(v.text) <= WordLimits.verse, "\(a.id) \(v.ref)") }
    }
}

private let contentDir = contentURL.deletingLastPathComponent()

@Test func shippedUnfoldDecodesAgainstShippedAnnotations() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let script = try UnfoldScript.decode(Data(contentsOf: contentDir.appendingPathComponent("unfold.json")), library: lib)
    #expect(script.beats.count == 8)
    #expect(script.beats.first?.id == "eden" && script.beats.last?.id == "rest-of-story")
}

@Test func shippedGlintPointsDecode() throws {
    let g = try GlintPoints.decode(Data(contentsOf: contentDir.appendingPathComponent("glints.json")))
    #expect(g.points.count >= 40)
}

@Test func shippedVersesHaveTheirTranslationNotice() throws {
    let licensed = try LicensedVerses.decode(Data(contentsOf: contentDir.appendingPathComponent("licensed-verses.json")))
    let raw = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let lib = raw.applying(licensed)
    let script = try UnfoldScript.decode(Data(contentsOf: contentDir.appendingPathComponent("unfold.json")), library: raw).applying(licensed)
    let notices = try Notices.decode(Data(contentsOf: contentDir.appendingPathComponent("notices.json")))
    let used = Set((lib.annotations.compactMap(\.more) + script.beats.compactMap(\.more)).flatMap(\.verses).map(\.translation))
    for t in used where t.needsNotice {
        #expect(notices.notices[t.rawValue] != nil, "\(t.rawValue) is quoted but has no copyright notice in notices.json")
    }
}

@Test func noticesRequiredOnlyForCopyrightedTranslations() {
    #expect(Translation.niv.needsNotice && Translation.esv.needsNotice && Translation.nlt.needsNotice)
    #expect(!Translation.dra.needsNotice && !Translation.bsb.needsNotice)
}

/// Breathing: no two shipped regions share a rhythm, so the wall never pulses in unison.
@Test func noTwoShippedRegionsBreatheInStep() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let ids = lib.annotations.filter { $0.outline != nil }.map(\.id)
    let breathing = Breathing(ids: ids)
    for (i, a) in ids.enumerated() {
        for b in ids[(i + 1)...] {
            let samePeriod = abs(breathing.period(for: a) - breathing.period(for: b)) < 0.15
            let samePhase = abs(breathing.phase(for: a) - breathing.phase(for: b)) < 0.08
            #expect(!(samePeriod && samePhase), "\(a) and \(b) breathe together")
        }
    }
}

/// Unfold: whatever a beat's words name must light up during that beat (Matt: beat 6 said
/// "The Angels" while the stag was lit). Words → the figures that satisfy them.
@Test func everyUnfoldBeatLightsWhatItTalksAbout() throws {
    let content = contentURL.deletingLastPathComponent()
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let script = try UnfoldScript.decode(Data(contentsOf: content.appendingPathComponent("unfold.json")), library: lib)
    let animals: Set<String> = ["stag", "fox", "bear", "lion", "beast", "raven", "pelican"]
    let named: [(words: [String], any: Set<String>)] = [
        (["angel"], ["angels"]),
        (["serpent"], ["snake", "basilisk"]),
        (["lion"], ["lion"]),
        (["jesus christ", "son of god"], ["christ"]),
        (["wild beasts", "animals"], animals),
    ]
    for b in script.beats {
        let text = [b.title, b.short, b.more?.story ?? ""].joined(separator: " ").lowercased()
        let lit = Set(b.light.joined())
        for n in named where n.words.contains(where: text.contains) {
            #expect(!lit.isDisjoint(with: n.any), "\(b.id) (“\(b.title)”) names \(n.words[0]) but lights \(lit.sorted())")
        }
    }
}

/// Context: each page lights what it names; and no page talks about the copy or "here"
/// (Matt: "no self referencing").
@Test func everyContextPageLightsWhatItNamesAndNeverTalksAboutThisCopy() throws {
    let content = contentURL.deletingLastPathComponent()
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let maps = try ContextMaps.decode(Data(contentsOf: content.appendingPathComponent("maps.json")))
    let s = try ContextScript.decode(Data(contentsOf: content.appendingPathComponent("context.json")), library: lib, maps: maps)
    let animals: Set<String> = ["stag", "fox", "bear", "lion", "beast", "raven", "pelican"]
    let named: [(words: [String], any: Set<String>)] = [
        (["angel"], ["angels"]), (["cherub"], ["fragment"]), (["beech"], ["tree"]),
        (["serpent"], ["snake", "basilisk"]), (["wild animals", "wild beasts"], animals),
    ]
    let banned = ["hangs here", "a copy", "home again", "this copy", "in this house"]
    for p in s.pages {
        let text = (p.title + " " + p.text).lowercased()
        for n in named where n.words.contains(where: text.contains) {
            #expect(!Set(p.light).isDisjoint(with: n.any), "\(p.id) names \(n.words[0]) but lights \(p.light)")
        }
        for b in banned { #expect(!text.contains(b), "\(p.id) talks about the copy: “\(b)”") }
    }
}

/// Text on the canvas: every shipped figure has a calm place that covers neither it nor Christ.
@Test func everyFigureHasARealTextPlaceAwayFromItAndChrist() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let zones = try TextZones.decode(Data(contentsOf: contentURL.deletingLastPathComponent()
        .appendingPathComponent("textzones.json"))).zones
    let christ = lib.annotations.first { $0.id == "christ" }!.outline!
    for a in lib.annotations where a.outline != nil {
        let z = try #require(CanvasText.zone(for: a.id, library: lib, zones: zones), "\(a.id) has no place")
        #expect(!CanvasText.overlaps(z, a.outline!), "\(a.id)'s text covers \(a.id)")
        #expect(!CanvasText.overlaps(z, christ), "\(a.id)'s text covers Christ")
    }
}
