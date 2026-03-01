import Foundation
import UIKit

@Observable
final class TerminalSession {
    let serverID: UUID
    let host: String
    let port: Int
    let username: String
    let sshService: SSHService

    @ObservationIgnored
    private(set) var scrollbackData: [UInt8] = []

    var lastKnownCols: Int = 80
    var lastKnownRows: Int = 24

    private static let maxScrollbackBytes = 1_048_576  // 1MB

    init(serverID: UUID, host: String, port: Int, username: String) {
        self.serverID = serverID
        self.host = host
        self.port = port
        self.username = username
        self.sshService = SSHService()
    }

    func appendToScrollback(_ bytes: [UInt8]) {
        scrollbackData.append(contentsOf: bytes)
        if scrollbackData.count > Self.maxScrollbackBytes {
            scrollbackData.removeFirst(scrollbackData.count - Self.maxScrollbackBytes)
        }
    }

    func clearScrollback() {
        scrollbackData.removeAll()
    }
}

@Observable
final class SessionManager {
    static let shared = SessionManager()

    private(set) var sessions: [UUID: TerminalSession] = [:]

    private var keepaliveTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {
        setupNotifications()
        startKeepaliveTimer()
    }

    // MARK: - Public API

    func hasActiveSession(for serverID: UUID) -> Bool {
        sessions[serverID]?.sshService.state == .connected
    }

    func session(for serverID: UUID) -> TerminalSession? {
        sessions[serverID]
    }

    func getOrCreateSession(for server: ServerConnection) async -> TerminalSession {
        if let existing = sessions[server.id] {
            switch existing.sshService.state {
            case .connected:
                return existing
            case .connecting:
                return existing
            case .disconnected, .failed:
                // Ensure clean state before reconnecting
                existing.sshService.disconnect()
                if let password = KeychainService.load(for: server.id) {
                    await existing.sshService.connect(
                        host: server.host,
                        port: server.port,
                        username: server.username,
                        password: password,
                        initialCols: existing.lastKnownCols,
                        initialRows: existing.lastKnownRows
                    )
                } else {
                    existing.sshService.state = .failed("No credentials found. Please edit this server.")
                }
                return existing
            }
        }

        // Create new session
        let session = TerminalSession(
            serverID: server.id,
            host: server.host,
            port: server.port,
            username: server.username
        )
        sessions[server.id] = session

        if let password = KeychainService.load(for: server.id) {
            await session.sshService.connect(
                host: server.host,
                port: server.port,
                username: server.username,
                password: password,
                initialCols: session.lastKnownCols,
                initialRows: session.lastKnownRows
            )
        } else {
            session.sshService.state = .failed("No credentials found. Please edit this server.")
        }

        return session
    }

    func terminateSession(for serverID: UUID) {
        guard let session = sessions[serverID] else { return }
        session.sshService.disconnect()
        session.clearScrollback()
        sessions.removeValue(forKey: serverID)
    }

    func sessionMovedToBackground(for serverID: UUID) {}

    func sessionMovedToForeground(for serverID: UUID) {}

    // MARK: - Background Task

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endBackgroundTask()
        }
    }

    private func handleBackground() {
        let hasConnected = sessions.values.contains { $0.sshService.state == .connected }
        guard hasConnected else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WrapSSHKeepalive") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // MARK: - Keepalive Timer

    private func startKeepaliveTimer() {
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.sendKeepaliveToAll()
        }
    }

    private func sendKeepaliveToAll() {
        for session in sessions.values where session.sshService.state == .connected {
            session.sshService.sendKeepalive()
        }
    }
}
