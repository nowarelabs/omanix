// modules/apps/store/Sources/FileLogger.swift
// Omanix — write structured logs to ~/.omanix/logs/
import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info  = "INFO"
    case warn  = "WARN"
    case error = "ERROR"
}

final class FileLogger {
    static let shared = FileLogger()

    private let logDir: String
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    private let queue = DispatchQueue(label: "dev.omanix.logger", qos: .utility)

    private init() {
        logDir = NSHomeDirectory() + "/.omanix/logs"
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        // Create log directory
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
    }

    func log(_ level: LogLevel, _ context: String, _ message: String) {
        let timestamp = timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(context)] \(message)"

        // Write to file (daily log)
        let filename = "\(dateFormatter.string(from: Date())).log"
        let filepath = (logDir as NSString).appendingPathComponent(filename)

        queue.async {
            let data = (line + "\n").data(using: .utf8) ?? Data()
            if FileManager.default.fileExists(atPath: filepath) {
                if let fh = FileHandle(forWritingAtPath: filepath) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: filepath, contents: data)
            }
        }
    }

    func debug(_ context: String, _ message: String) { log(.debug, context, message) }
    func info(_ context: String, _ message: String)  { log(.info, context, message) }
    func warn(_ context: String, _ message: String)  { log(.warn, context, message) }
    func error(_ context: String, _ message: String) { log(.error, context, message) }

    func rotate() {
        queue.async {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: self.logDir) else { return }
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -30, to: Date())!
            for file in files {
                guard file.hasSuffix(".log") else { continue }
                let path = (self.logDir as NSString).appendingPathComponent(file)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let created = attrs[.creationDate] as? Date,
                      created < cutoff else { continue }
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }
}
