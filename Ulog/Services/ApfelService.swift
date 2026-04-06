#if canImport(AppKit)
import AppKit
#endif
import Foundation

@Observable
class ApfelService {
    enum Status: Equatable {
        case stopped
        case starting
        case ready
        case error(String)
    }

    private(set) var status: Status = .stopped
    private var process: Process?
    private let port: Int
    private let binaryPath: String

    var baseURL: URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = port

        guard let url = components.url else {
            preconditionFailure("Invalid base URL configuration for port \(port)")
        }

        return url
    }

    init(port: Int = 11438) {
        self.port = port
        self.binaryPath = Self.findApfelBinary()

        #if os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
        #endif
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() async {
        guard status != .starting && status != .ready else { return }

        // Check if apfel is already running externally
        if await checkHealth() {
            status = .ready
            return
        }

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            status = .error("apfel not found. Install with: brew install apfel")
            return
        }

        status = .starting

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["--serve", "--port", "\(port)", "--cors"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            self.process = proc

            let ready = await waitForServer(timeout: 30)
            if ready {
                status = .ready
            } else {
                status = .error("apfel server failed to start within 30 seconds")
                stop()
            }
        } catch {
            status = .error("Failed to start apfel: \(error.localizedDescription)")
        }
    }

    func stop() {
        if let process = process, process.isRunning {
            process.terminate()
        }
        process = nil
        if status != .stopped {
            status = .stopped
        }
    }

    func setStatusForTesting(_ status: Status) {
        self.status = status
    }

    // MARK: - Health Check

    private func waitForServer(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await checkHealth() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    private func checkHealth() async -> Bool {
        let url = baseURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return true
            }
        } catch {}
        return false
    }

    // MARK: - Binary Discovery

    private static func findApfelBinary() -> String {
        let knownPaths = [
            "/opt/homebrew/bin/apfel",
            "/usr/local/bin/apfel"
        ]
        for path in knownPaths where FileManager.default.fileExists(atPath: path) {
            return path
        }

        // Fallback: use `which` to locate the binary
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["apfel"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result.isEmpty ? "/opt/homebrew/bin/apfel" : result
    }
}
