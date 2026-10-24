import Darwin
import Foundation

/// "Playing <game>" on the player's Discord profile, through the Discord app's local socket (the documented
/// Rich Presence IPC: a handshake, then SET_ACTIVITY). Nothing goes to the network from UniveGame; when Discord
/// isn't running, nothing happens.
final class DiscordPresence: @unchecked Sendable {
    /// The "UniveGame" application on discord.com/developers. Rich Presence shows nothing without one; empty turns
    /// the feature off.
    static let clientID = Bundle.main.object(forInfoDictionaryKey: "UniveGameDiscordClientID") as? String ?? ""
    static var isAvailable: Bool { !clientID.isEmpty && clientID.allSatisfy(\.isNumber) }

    private let queue = DispatchQueue(label: "univegame.discord")
    private var socket: Int32 = -1

    deinit { if socket >= 0 { close(socket) } }

    /// Shows `title` as the game being played since `start`; nil clears it.
    func show(_ title: String?, since start: Date = Date()) {
        guard Self.isAvailable else { return }
        let pid = ProcessInfo.processInfo.processIdentifier
        queue.async { [self] in
            guard connect() else { return }
            var args: [String: Any] = ["pid": pid]
            if let title {
                args["activity"] = ["details": String(title.prefix(128)), "state": "on a Mac, with UniveGame",
                                    "timestamps": ["start": Int(start.timeIntervalSince1970)]]
            }
            let command: [String: Any] = ["cmd": "SET_ACTIVITY", "args": args, "nonce": UUID().uuidString]
            if !send(op: 1, command) || !readFrame() { disconnect() }
        }
    }

    // MARK: IPC

    /// One frame: opcode and length (little-endian UInt32), then the JSON.
    static func frame(op: UInt32, _ object: [String: Any]) -> Data? {
        guard let json = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        var data = Data()
        withUnsafeBytes(of: op.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(json.count).littleEndian) { data.append(contentsOf: $0) }
        return data + json
    }

    /// Discord listens on `discord-ipc-0` … `-9` in the user's temporary folder.
    static func socketPaths() -> [String] {
        let tmp = (ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory())
        return (0...9).map { (tmp as NSString).appendingPathComponent("discord-ipc-\($0)") }
    }

    private func connect() -> Bool {
        if socket >= 0 { return true }
        for path in Self.socketPaths() where FileManager.default.fileExists(atPath: path) {
            let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8)
            guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { close(fd); continue }
            withUnsafeMutableBytes(of: &addr.sun_path) { raw in
                raw.copyBytes(from: bytes)
                raw[bytes.count] = 0
            }
            let ok = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            } == 0
            guard ok else { close(fd); continue }
            var noSigPipe: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            var timeout = timeval(tv_sec: 2, tv_usec: 0)   // a Discord that doesn't answer must not hold the queue
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            socket = fd
            if send(op: 0, ["v": 1, "client_id": Self.clientID]), readFrame() { return true }
            disconnect()
        }
        return false
    }

    private func send(op: UInt32, _ object: [String: Any]) -> Bool {
        guard socket >= 0, let data = Self.frame(op: op, object) else { return false }
        let written = data.withUnsafeBytes { write(socket, $0.baseAddress, data.count) }
        return written == data.count
    }

    /// Reads (and discards) one reply, so the socket doesn't fill up.
    private func readFrame() -> Bool {
        var header = [UInt8](repeating: 0, count: 8)
        guard read(socket, &header, 8) == 8 else { return false }
        let length = Int(header[4]) | Int(header[5]) << 8 | Int(header[6]) << 16 | Int(header[7]) << 24
        guard length >= 0, length < 1 << 20 else { return false }
        var body = [UInt8](repeating: 0, count: length)
        var got = 0
        while got < length {
            let n = body.withUnsafeMutableBytes { read(socket, $0.baseAddress! + got, length - got) }
            if n <= 0 { return false }
            got += n
        }
        return true
    }

    private func disconnect() {
        if socket >= 0 { close(socket) }
        socket = -1
    }
}
