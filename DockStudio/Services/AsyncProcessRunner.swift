import Foundation
import Darwin

struct AsyncProcessRunner {
    struct Output {
        let stdout: Data
        let stderr: Data
        let status: Int32
        let timedOut: Bool
    }

    func run(executable: URL, arguments: [String], timeout: TimeInterval = 10) async throws -> Output {
        let result = try await Task.detached {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: directory) }
            let stdoutURL = directory.appendingPathComponent("stdout")
            let stderrURL = directory.appendingPathComponent("stderr")
            FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            let stdout = try FileHandle(forWritingTo: stdoutURL)
            let stderr = try FileHandle(forWritingTo: stderrURL)
            defer { try? stdout.close(); try? stderr.close() }
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
            let expiration = ProcessExpiration()
            let timeoutWork = DispatchWorkItem { expiration.expire(process) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
            process.waitUntilExit()
            timeoutWork.cancel()
            return Output(stdout: try Data(contentsOf: stdoutURL), stderr: try Data(contentsOf: stderrURL),
                          status: process.terminationStatus, timedOut: expiration.expired)
        }.value
        try Task.checkCancellation()
        return result
    }
}

private final class ProcessExpiration: @unchecked Sendable {
    private let lock = NSLock()
    private var didExpire = false
    var expired: Bool { lock.withLock { didExpire } }
    func expire(_ process: Process) {
        lock.withLock {
            if process.isRunning {
                didExpire = true
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
                }
            }
        }
    }
}
