import SwiftUI
import SwiftData

struct ServerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @Query(sort: \ServerConnection.name) private var servers: [ServerConnection]
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var activeRoute: SessionRoute?

    // MARK: - Session route wrapper for fullScreenCover

    private struct SessionRoute: Identifiable {
        let id = UUID()
        let server: ServerConnection
        let session: TerminalSession?
    }

    // MARK: - Filtered / grouped helpers

    private var filteredServers: [ServerConnection] {
        if searchText.isEmpty { return servers }
        let query = searchText.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(query)
                || $0.host.lowercased().contains(query)
                || $0.username.lowercased().contains(query)
        }
    }

    private var groupedServers: [(String, [ServerConnection])] {
        let ungroupedKey = ""
        var groups: [String: [ServerConnection]] = [:]
        for server in filteredServers {
            let key = server.group ?? ungroupedKey
            groups[key, default: []].append(server)
        }
        return groups.sorted { lhs, rhs in
            if lhs.key == ungroupedKey { return false }
            if rhs.key == ungroupedKey { return true }
            return lhs.key < rhs.key
        }
    }

    /// All connected sessions whose server matches the current search filter,
    /// sorted by creation time, with a 1-based index per server for the "(x)" suffix.
    private var activeSessions: [(session: TerminalSession, server: ServerConnection, index: Int)] {
        let serverMap = Dictionary(uniqueKeysWithValues: servers.map { ($0.id, $0) })
        let filteredIDs = Set(filteredServers.map { $0.id })

        let connected = sessionManager.sessions.values
            .filter { $0.sshService.state == .connected && filteredIDs.contains($0.serverID) }
            .sorted { $0.createdAt < $1.createdAt }

        var countByServer: [UUID: Int] = [:]
        return connected.compactMap { session in
            guard let server = serverMap[session.serverID] else { return nil }
            let idx = countByServer[session.serverID, default: 0] + 1
            countByServer[session.serverID] = idx
            return (session: session, server: server, index: idx)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if servers.isEmpty {
                    emptyState
                } else {
                    serverList
                }
            }
            .navigationTitle("Wrap")
            .searchable(text: $searchText, prompt: "Search servers...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ServerFormView()
            }
            .fullScreenCover(item: $activeRoute) { route in
                TerminalSessionView(server: route.server, session: route.session)
            }
            .sheet(item: $editingServer) { server in
                ServerFormView(server: server)
            }
            .alert("Disconnect Session?", isPresented: Binding(
                get: { terminatingSession != nil },
                set: { if !$0 { terminatingSession = nil } }
            )) {
                Button("Disconnect", role: .destructive) {
                    if let ts = terminatingSession {
                        sessionManager.terminateSession(sessionID: ts.session.id)
                    }
                    terminatingSession = nil
                }
                Button("Cancel", role: .cancel) { terminatingSession = nil }
            } message: {
                if let ts = terminatingSession {
                    Text("Close the active SSH session for \(ts.server.name)?")
                }
            }
            .alert("Delete Server?", isPresented: Binding(
                get: { deletingServer != nil },
                set: { if !$0 { deletingServer = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let server = deletingServer {
                        deleteServer(server)
                    }
                    deletingServer = nil
                }
                Button("Cancel", role: .cancel) { deletingServer = nil }
            } message: {
                if let server = deletingServer {
                    Text("\"\(server.name)\" will be permanently removed.")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Welcome to Wrap", systemImage: "terminal")
        } description: {
            Text("Your SSH terminal in pocket.\nAdd a server to get started.")
        } actions: {
            Button {
                showAddSheet = true
            } label: {
                Text("Add Server")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Server list

    private var serverList: some View {
        List {
            if !activeSessions.isEmpty {
                Section("Active") {
                    ForEach(activeSessions, id: \.session.id) { item in
                        activeRow(item.session, server: item.server, index: item.index)
                    }
                }
            }

            ForEach(groupedServers, id: \.0) { group, groupServers in
                Section(group.isEmpty ? "Servers" : group) {
                    ForEach(groupServers) { server in
                        serverRow(server)
                    }
                }
            }
        }
    }

    // MARK: - Active row

    private func activeRow(_ session: TerminalSession, server: ServerConnection, index: Int) -> some View {
        let displayName = index > 1 ? "\(server.name) (\(index))" : server.name

        return Button {
            activeRoute = SessionRoute(server: server, session: session)
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.green, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }

                    Text("\(server.username)@\(server.host):\(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                Spacer()

                Button {
                    terminatingSession = TerminatingSession(session: session, server: server)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                sessionManager.terminateSession(sessionID: session.id)
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }
            .tint(.red)
        }
    }

    // MARK: - Server row

    private func serverRow(_ server: ServerConnection) -> some View {
        Button {
            activeRoute = SessionRoute(server: server, session: nil)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("\(server.username)@\(server.host):\(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deletingServer = server
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                editingServer = server
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = "\(server.username)@\(server.host)"
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }

            Button {
                UIPasteboard.general.string = "ssh \(server.username)@\(server.host) -p \(server.port)"
            } label: {
                Label("Copy SSH Command", systemImage: "terminal")
            }

            Divider()

            Button {
                editingServer = server
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deletingServer = server
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - State + helpers

    @State private var editingServer: ServerConnection?
    @State private var deletingServer: ServerConnection?

    private struct TerminatingSession {
        let session: TerminalSession
        let server: ServerConnection
    }
    @State private var terminatingSession: TerminatingSession?

    private func deleteServer(_ server: ServerConnection) {
        sessionManager.terminateSession(for: server.id)
        KeychainService.delete(for: server.id)
        modelContext.delete(server)
    }
}
