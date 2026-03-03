// SocketService.swift
// Unix domain socket server for toggle/status commands
// Compatible with vox CLI and Hammerspoon

import Foundation

final class SocketService: @unchecked Sendable {

    /// Callback when a command is received, returns a response string
    var onCommand: ((String) async -> String)?

    private let sockPath = "/tmp/voxtype.sock"
    private var serverFD: Int32 = -1
    private var thread: Thread?
    private var running = false

    func start() {
        thread = Thread { [weak self] in
            self?.serve()
        }
        thread?.name = "VoxType.SocketService"
        thread?.start()
    }

    func stop() {
        running = false

        // Close server socket
        if serverFD >= 0 {
            Darwin.close(serverFD)
            serverFD = -1
        }

        // Clean up socket file
        unlink(sockPath)

        thread?.cancel()
    }

    // MARK: - Internal

    private func serve() {
        // Remove stale socket
        unlink(sockPath)

        // Create Unix domain socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            print("[VoxType] Failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy sun_path using a local variable to avoid overlapping access
        var sunPath = addr.sun_path
        sockPath.withCString { cstr in
            withUnsafeMutableBytes(of: &sunPath) { rawBuf in
                guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                strncpy(ptr, cstr, rawBuf.count - 1)
            }
        }
        addr.sun_path = sunPath

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverFD, sockaddrPtr, addrLen)
            }
        }

        listen(serverFD, 5)
        chmod(sockPath, 0o600)

        running = true
        print("[VoxType] Socket service ready: \(sockPath)")

        while running {
            let clientFD = accept(serverFD, nil, nil)
            guard clientFD >= 0 else { continue }

            // Read command
            var buffer = [UInt8](repeating: 0, count: 64)
            let bytesRead = read(clientFD, &buffer, buffer.count)

            if bytesRead > 0 {
                let command = String(bytes: buffer[..<bytesRead], encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // Process command asynchronously
                let semaphore = DispatchSemaphore(value: 0)
                nonisolated(unsafe) var response = "error"

                Task { @Sendable in
                    if let handler = self.onCommand {
                        response = await handler(command)
                    }
                    semaphore.signal()
                }

                semaphore.wait()

                // Send response
                response.withCString { cstr in
                    _ = write(clientFD, cstr, strlen(cstr))
                }
            }

            Darwin.close(clientFD)
        }
    }
}
