// SocketService.swift
// Unix domain socket 服务，接收 toggle/status 指令
// 兼容 vox CLI 和 Hammerspoon

import Foundation

final class SocketService: @unchecked Sendable {

    /// 收到命令时的回调，返回响应字符串
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

        // 关闭 server socket
        if serverFD >= 0 {
            Darwin.close(serverFD)
            serverFD = -1
        }

        // 清理 socket 文件
        unlink(sockPath)

        thread?.cancel()
    }

    // MARK: - 内部

    private func serve() {
        // 清理旧 socket
        unlink(sockPath)

        // 创建 Unix domain socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            print("[VoxType] 无法创建 socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // 用局部变量复制 sun_path 避免 overlapping access
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
        print("[VoxType] Socket 服务就绪: \(sockPath)")

        while running {
            let clientFD = accept(serverFD, nil, nil)
            guard clientFD >= 0 else { continue }

            // 读取命令
            var buffer = [UInt8](repeating: 0, count: 64)
            let bytesRead = read(clientFD, &buffer, buffer.count)

            if bytesRead > 0 {
                let command = String(bytes: buffer[..<bytesRead], encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // 异步处理命令
                let semaphore = DispatchSemaphore(value: 0)
                nonisolated(unsafe) var response = "error"

                Task { @Sendable in
                    if let handler = self.onCommand {
                        response = await handler(command)
                    }
                    semaphore.signal()
                }

                semaphore.wait()

                // 发送响应
                response.withCString { cstr in
                    _ = write(clientFD, cstr, strlen(cstr))
                }
            }

            Darwin.close(clientFD)
        }
    }
}
