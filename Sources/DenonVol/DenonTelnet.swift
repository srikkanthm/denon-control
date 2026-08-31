import Foundation
import Darwin

final class DenonTelnet {
    let host: String
    let port: UInt16

    init(host: String, port: UInt16 = 23) {
        self.host = host
        self.port = port
    }

    func send(_ command: String) {
        DispatchQueue(label: "denon.telnet", qos: .userInitiated).async {
            _ = self.execute(command)
        }
    }

    private func execute(_ command: String) -> String? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = resolve(host)

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                connect(fd, pointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else { return nil }

        let payload = command + "\r"
        let sent = payload.withCString { Darwin.send(fd, $0, payload.count, 0) }
        guard sent == payload.count else { return nil }

        var response = ""
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = recv(fd, &buffer, buffer.count, 0)
            if n <= 0 { break }
            response += String(decoding: buffer[0..<n], as: UTF8.self)
        }
        return response
    }

    private func resolve(_ host: String) -> in_addr {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>? = nil
        guard getaddrinfo(host, nil, &hints, &res) == 0, let found = res else {
            if let res { freeaddrinfo(res) }
            return in_addr()
        }
        defer { freeaddrinfo(found) }
        let sin = UnsafeRawPointer(found.pointee.ai_addr)
            .assumingMemoryBound(to: sockaddr_in.self).pointee
        return sin.sin_addr
    }
}