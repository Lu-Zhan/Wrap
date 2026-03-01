import Foundation
import UIKit

@Observable
final class TerminalSession {
    let id: UUID
    let serverID: UUID
    let createdAt: Date
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
        self.id = UUID()
        self.serverID = serverID
        self.createdAt = Date()
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

    /// Keyed by session.id (not serverID) to support multiple sessions per server
    private(set) var sessions: [UUID: TerminalSession] = [:]

    private var keepaliveTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {
        setupNotifications()
        startKeepaliveTimer()
    }

    // MARK: - Public API

    func hasActiveSession(for serverID: UUID) -> Bool {
        sessions.values.contains { $0.serverID == serverID && $0.sshService.state == .connected }
    }

    func session(for serverID: UUID) -> TerminalSession? {
        sessions.values
            .filter { $0.serverID == serverID }
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }

    func sessions(for serverID: UUID) -> [TerminalSession] {
        sessions.values
            .filter { $0.serverID == serverID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Always creates a brand-new SSH session for the given server.
    func createNewSession(for server: ServerConnection) async -> TerminalSession {
        let session = TerminalSession(
            serverID: server.id,
            host: server.host,
            port: server.port,
            username: server.username
        )
        sessions[session.id] = session

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

    /// Reconnects a specific session that has disconnected or failed.
    func reconnect(_ session: TerminalSession, for server: ServerConnection) async {
        switch session.sshService.state {
        case .connected, .connecting:
            return
        case .disconnected, .failed:
            session.sshService.disconnect()
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
        }
    }

    /// Terminates one specific session by its own session ID.
    func terminateSession(sessionID: UUID) {
        guard let session = sessions[sessionID] else { return }
        session.sshService.disconnect()
        session.clearScrollback()
        sessions.removeValue(forKey: sessionID)
    }

    /// Terminates all sessions for a given server (used when deleting a server).
    func terminateSession(for serverID: UUID) {
        let toTerminate = sessions.values.filter { $0.serverID == serverID }
        for session in toTerminate {
            session.sshService.disconnect()
            session.clearScrollback()
            sessions.removeValue(forKey: session.id)
        }
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
