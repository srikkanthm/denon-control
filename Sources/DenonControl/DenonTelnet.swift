import Foundation
import Darwin

final class DenonTelnet {
    private static let ioQueue = DispatchQueue(label: "denon.telnet.io", qos: .userInitiated)

    func send(_ command: String, host: String, port: UInt16 = 23) {
        Self.ioQueue.async {
            _ = self.execute(command, host: host, port: port)
        }
    }

    func query(_ command: String, host: String, port: UInt16 = 23, completion: @escaping (String?) -> Void) {
        Self.ioQueue.async {
            let response = self.execute(command, host: host, port: port)
            DispatchQueue.main.async {
                completion(response)
            }
        }
    }

    private func execute(_ command: String, host: String, port: UInt16) -> String? {
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

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                connect(fd, pointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 || errno == EINPROGRESS || errno == EISCONN else { return nil }
        if connectResult != 0 {
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            guard poll(&pfd, 1, 2000) > 0, pfd.revents & Int16(POLLOUT) != 0 else { return nil }
            var socketError: Int32 = 0
            var errorSize = socklen_t(MemoryLayout<Int32>.size)
            guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &errorSize) == 0,
                  socketError == 0 else { return nil }
        }
        _ = fcntl(fd, F_SETFL, flags)

        let payload = command + "\r"
        let sent = payload.withCString { Darwin.send(fd, $0, payload.count, 0) }
        guard sent == payload.count else { return nil }

        var response = ""
        var buffer = [UInt8](repeating: 0, count: 4096)
        var gotData = false
        var iterations = 0
        while iterations < 64 {
            iterations += 1
            let n = recv(fd, &buffer, buffer.count, 0)
            if n <= 0 { break }
            response += String(decoding: buffer[0..<n], as: UTF8.self)
            guard !gotData else { continue }
            gotData = true
            var idleTimeout = timeval(tv_sec: 0, tv_usec: 600_000)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &idleTimeout, socklen_t(MemoryLayout<timeval>.size))
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