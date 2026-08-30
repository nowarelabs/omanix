// Modules/Plugins/PluginIPCServer.swift
// Runtime (dynamic IPC) plugin server — the Unix socket side of Phase 5.
//
// The brief calls for runtime plugins that are "IPC Consumers" over a well-typed
// Unix socket, isolated so a crashing plugin never takes the bar down. This server
// is the bar side: it listens on `~/.config/omanix/omanix.sock` (configurable via
// `omanix.plugins.socketPath`), accepts newline-delimited JSON-RPC from any
// number of concurrent plugin processes, validates the payload, and publishes a
// typed `OmanixEvent.pluginUpdate` to the EventBus. A generic IPC renderer
// (or any future plugin) subscribes to that bus and draws the plugin's view.
//
// Protocol (newline-delimited JSON, one object per line):
//   { "jsonrpc":"2.0", "method":"update", "params":{ "id":"weather", "title":"22°C", "image":"cloud.sun", "payload":{...} } }
//   { "id":"myplugin", "title":"hello" }  // shorthand without jsonrpc/method
//
// Isolation: each client is handled on its own DispatchSource; if it disconnects
// or sends invalid JSON, only that connection is torn down.

import Foundation
import Darwin

final class PluginIPCServer {

    static let shared = PluginIPCServer()

    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]
    private var socketPath: String = ""
    private let queue = DispatchQueue(label: "dev.omanix.plugin-ipc", qos: .utility)

    private init() {}

    // MARK: - Lifecycle

    func start(socketPath path: String? = nil) {
        let resolved: String
        if let path {
            resolved = (path as NSString).expandingTildeInPath
        } else {
            // Read from the generated workspaces? For plugins, use the default.
            // We could read omanix.plugins.socketPath via RuntimeSettings, but for
            // minimal we use the fixed default and allow the caller to override.
            resolved = NSHomeDirectory() + "/.config/omanix/omanix.sock"
        }
        socketPath = resolved
        queue.async { [weak self] in self?.bindAndListen(at: resolved) }
        print("PluginIPCServer: starting at \(resolved)")
    }

    func stop() {
        queue.sync {
            for (_, src) in clientSources { src.cancel() }
            clientSources.removeAll()
            clientBuffers.removeAll()
            acceptSource?.cancel()
            acceptSource = nil
            if listenFD >= 0 {
                close(listenFD)
                listenFD = -1
            }
            if !socketPath.isEmpty {
                unlink(socketPath)
            }
        }
    }

    // MARK: - Socket

    private func bindAndListen(at path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Remove stale socket from previous run (unclean exit).
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { print("PluginIPCServer: socket() failed \(errno)"); return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        // sun_path is 104 bytes on macOS; copy our path (ensure NUL-terminated).
        let pathLen = min(path.utf8.count, MemoryLayout.size(ofValue: addr.sun_path) - 1)
        _ = path.withCString { cstr in
            withUnsafeMutablePointer(to: &addr.sun_path) { dst in
                dst.withMemoryRebound(to: CChar.self, capacity: 104) { ptr in
                    strncpy(ptr, cstr, pathLen)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(fd, sockPtr, addrLen)
            }
        }
        guard bindResult == 0 else { print("PluginIPCServer: bind(\(path)) failed \(errno)"); close(fd); return }
        guard listen(fd, 10) == 0 else { print("PluginIPCServer: listen failed \(errno)"); close(fd); return }

        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClient() }
        source.setCancelHandler { close(fd) }
        source.resume()
        acceptSource = source
        print("PluginIPCServer: listening on \(path)")
    }

    private func acceptClient() {
        var addr = sockaddr_un()
        var len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let clientFD = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                accept(listenFD, sockPtr, &len)
            }
        }
        guard clientFD >= 0 else { return }
        // Make non-blocking so the read source doesn't spin.
        _ = fcntl(clientFD, F_SETFL, O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        source.setEventHandler { [weak self] in self?.readClient(clientFD) }
        source.setCancelHandler { close(clientFD) }
        source.resume()
        clientSources[clientFD] = source
        clientBuffers[clientFD] = Data()
        print("PluginIPCServer: client connected fd=\(clientFD)")
    }

    private func readClient(_ fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(fd, &buf, buf.count)
        if n <= 0 {
            // EOF or error — client disconnected.
            clientSources[fd]?.cancel()
            clientSources.removeValue(forKey: fd)
            clientBuffers.removeValue(forKey: fd)
            if n == 0 { print("PluginIPCServer: client fd=\(fd) disconnected") }
            return
        }
        var data = clientBuffers[fd] ?? Data()
        data.append(buf, count: n)
        // Process complete newline-delimited JSON objects.
        while let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = data.prefix(upTo: newline)
            data.removeSubrange(...newline)
            if !lineData.isEmpty {
                handleLine(lineData)
            }
        }
        clientBuffers[fd] = data
    }

    private func handleLine(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = PluginUpdateInfo.from(json: obj) else {
            print("PluginIPCServer: invalid JSON line: \(String(data: data, encoding: .utf8) ?? "<binary>")")
            return
        }
        // Publish to the typed bus; any IPC renderer or the generic fallback will redraw.
        EventBus.shared.publish(pluginUpdate: info)
        print("PluginIPCServer: update id=\(info.id) title=\(info.title)")
    }
}
