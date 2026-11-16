import Foundation
import Network
import os
import WildernessCore

/// The phone side of the companion: finds "The Wilderness" on the home network (Bonjour
/// `_wilderness._tcp`), connects, sends commands and keeps the latest WallSnapshot. If the
/// Apple TV goes away (restart, sleep, app closed) it says so and keeps looking.
@MainActor
final class CompanionClient: ObservableObject {
    enum Link: Equatable { case searching, connecting, connected }

    @Published private(set) var link: Link = .searching
    @Published private(set) var snapshot: WallSnapshot?

    private nonisolated static let log = Logger(subsystem: "com.mattmccoy.wilderness.phone", category: "companion")
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var framer = LineFramer()
    /// Walls that dropped or never answered, oldest first (see WallPicker).
    private var recentlyFailed: [String] = []
    private var currentName: String?

    func start() {
        guard browser == nil, connection == nil else { return }
        // Tests: `-companionHost 127.0.0.1:52741` connects directly instead of browsing Bonjour.
        if let direct = UserDefaults.standard.string(forKey: "companionHost"),
           let colon = direct.lastIndex(of: ":"), let n = UInt16(direct[direct.index(after: colon)...]),
           let port = NWEndpoint.Port(rawValue: n) {
            connect(to: .hostPort(host: NWEndpoint.Host(String(direct[..<colon])), port: port))
            return
        }
        let b = NWBrowser(for: .bonjour(type: "_wilderness._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self, self.connection == nil else { return }
                let named = results.compactMap { r -> (String, NWEndpoint)? in
                    if case let .service(name, _, _, _) = r.endpoint { return (name, r.endpoint) }
                    return nil
                }
                guard let name = WallPicker.pick(named.map(\.0), recentlyFailed: self.recentlyFailed),
                      let endpoint = named.first(where: { $0.0 == name })?.1 else { return }
                self.currentName = name
                self.connect(to: endpoint)
            }
        }
        b.stateUpdateHandler = { state in
            if case let .failed(error) = state { Self.log.error("browse failed: \(error.localizedDescription)") }
        }
        b.start(queue: .main)
        browser = b
    }

    func send(_ command: PhoneCommand) {
        guard link == .connected, let connection, let data = try? LineFramer.frame(command) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func connect(to endpoint: NWEndpoint) {
        link = .connecting
        framer = LineFramer()
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true     // notice an Apple TV that lost power or Wi-Fi
        tcp.keepaliveIdle = 10
        tcp.keepaliveInterval = 5
        tcp.keepaliveCount = 3
        let c = NWConnection(to: endpoint, using: NWParameters(tls: nil, tcp: tcp))
        connection = c
        // Never sit at "Connecting…": give up after 8 s and look again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.connection === c, self.link == .connecting else { return }
            self.drop()
        }
        c.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, self.connection === c else { return }
                switch state {
                case .ready:
                    self.link = .connected
                    if let n = self.currentName { self.recentlyFailed.removeAll { $0 == n } }
                    self.send(.hello)
                case .failed, .cancelled, .waiting:
                    // .waiting: the Apple TV refused or is gone; drop and browse again.
                    self.drop()
                default:
                    break
                }
            }
        }
        c.start(queue: .main)
        receive(on: c)
    }

    private func receive(on c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, done, error in
            Task { @MainActor in
                guard let self, self.connection === c else { return }
                if let data {
                    for line in self.framer.push(data) {
                        if let s = try? JSONDecoder().decode(WallSnapshot.self, from: line) { self.snapshot = s }
                    }
                }
                if done || error != nil { self.drop() } else { self.receive(on: c) }
            }
        }
    }

    /// Lost the Apple TV: forget it and look again (a fresh browse finds it when it returns).
    private func drop() {
        if let n = currentName {
            recentlyFailed.removeAll { $0 == n }
            recentlyFailed.append(n)
            currentName = nil
        }
        connection?.cancel()
        connection = nil
        snapshot = nil
        link = .searching
        browser?.cancel()
        browser = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.start() }
    }
}
