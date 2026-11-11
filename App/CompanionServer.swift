import Foundation
import Network
import os
import WildernessCore

/// The Apple TV side of the phone companion: advertises `_wilderness._tcp` on the local network,
/// accepts any number of phones, passes their commands to the app, and sends every phone the
/// current WallSnapshot whenever it changes (and on connect). Local network only, no accounts.
@MainActor
final class CompanionServer {
    static let serviceType = "_wilderness._tcp"
    private static let log = Logger(subsystem: "com.mattmccoy.wilderness", category: "companion")

    var onCommand: ((PhoneCommand) -> Void)?
    private var listener: NWListener?
    private var peers: [ObjectIdentifier: Peer] = [:]
    private var last: Data?

    func start() {
        guard listener == nil else { return }
        Self.log.notice("companion start requested")
        do {
            // Tests: `-companionPort N` listens on a fixed port, so simulators (which cannot
            // advertise over Bonjour on this Mac) can be connected directly.
            let fixed = UserDefaults.standard.integer(forKey: "companionPort")
            let l = try fixed > 0 ? NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: UInt16(fixed)))
                                  : NWListener(using: .tcp)
            l.service = NWListener.Service(name: "The Wilderness", type: Self.serviceType)
            l.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in self?.accept(conn) }
            }
            l.stateUpdateHandler = { state in
                Self.log.notice("companion listener state: \(String(describing: state), privacy: .public)")
            }
            l.serviceRegistrationUpdateHandler = { change in
                Self.log.notice("companion bonjour: \(String(describing: change), privacy: .public)")
            }
            l.start(queue: .main)
            listener = l
        } catch {
            Self.log.error("could not start companion listener: \(error.localizedDescription)")
        }
    }

    /// Sends the snapshot to every phone, and remembers it for phones that connect later.
    func broadcast(_ snapshot: WallSnapshot) {
        guard let data = try? LineFramer.frame(snapshot), data != last else { return }
        last = data
        for p in peers.values { p.send(data) }
    }

    private func accept(_ conn: NWConnection) {
        let peer = Peer(conn)
        let key = ObjectIdentifier(peer)
        peers[key] = peer
        peer.onCommand = { [weak self] c in self?.onCommand?(c) }
        peer.onClose = { [weak self] in self?.peers[key] = nil }
        peer.start()
        if let last { peer.send(last) }
    }

    /// One phone connection: reads newline-delimited commands, writes snapshots.
    @MainActor
    private final class Peer {
        let conn: NWConnection
        var framer = LineFramer()
        var onCommand: ((PhoneCommand) -> Void)?
        var onClose: (() -> Void)?

        init(_ conn: NWConnection) { self.conn = conn }

        func start() {
            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .failed, .cancelled: Task { @MainActor in self?.onClose?() }
                default: break
                }
            }
            conn.start(queue: .main)
            receive()
        }

        func send(_ data: Data) {
            conn.send(content: data, completion: .contentProcessed { _ in })
        }

        private func receive() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let data {
                        for line in self.framer.push(data) {
                            if let c = try? JSONDecoder().decode(PhoneCommand.self, from: line) { self.onCommand?(c) }
                        }
                    }
                    if done || error != nil { self.conn.cancel(); self.onClose?() } else { self.receive() }
                }
            }
        }
    }
}
