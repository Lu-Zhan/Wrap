import SwiftUI
import SwiftData

struct ServerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @Query(sort: \ServerConnection.name) private var servers: [ServerConnection]
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var selectedServer: ServerConnection?

    private var filteredServers: [ServerConnection] {
        if searchText.isEmpty { return servers }
        let query = searchText.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(query)
                || $0.host.lowercased().contains(query)
                || $0.username.lowercased().contains(query)
        }
    }

    private var recentServers: [ServerConnection] {
        filteredServers
            .filter { $0.lastConnectedAt != nil }
            .sorted { ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast) }
            .prefix(3)
            .map { $0 }
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
            .fullScreenCover(item: $selectedServer) { server in
                TerminalSessionView(server: server)
            }
            .sheet(isPresented: $showEditSheet) {
                if let editingServer {
                    ServerFormView(server: editingServer)
                }
            }
            .alert("Disconnect Session?", isPresented: Binding(
                get: { terminatingServer != nil },
                set: { if !$0 { terminatingServer = nil } }
            )) {
                Button("Disconnect", role: .destructive) {
                    if let server = terminatingServer {
                        sessionManager.terminateSession(for: server.id)
                    }
                    terminatingServer = nil
                }
                Button("Cancel", role: .cancel) { terminatingServer = nil }
            } message: {
                if let server = terminatingServer {
                    Text("Close the active SSH session for \(server.name)?")
                }
            }
        }
    }

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

    private var serverList: some View {
        List {
            if !recentServers.isEmpty {
                Section("Recent") {
                    ForEach(recentServers) { server in
                        serverRow(server)
                    }
                }
            }

            ForEach(groupedServers, id: \.0) { group, servers in
                Section(group.isEmpty ? "Servers" : group) {
                    ForEach(servers) { server in
                        serverRow(server)
                    }
                }
            }
        }
    }

    private func serverRow(_ server: ServerConnection) -> some View {
        let isLive = sessionManager.hasActiveSession(for: server.id)

        return Button {
            selectedServer = server
        } label: {
            HStack {
                if isLive {
                    ZStack {
                        Circle()
                            .stroke(Color.green, lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                } else {
                    Circle()
                        .fill(server.lastConnectedAt != nil ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        if isLive {
                            Text("LIVE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text("\(server.username)@\(server.host):\(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()

                }

                Spacer()

                if isLive {
                    Button {
                        terminatingServer = server
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteServer(server)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                editingServer = server
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)

            if isLive {
                Button {
                    sessionManager.terminateSession(for: server.id)
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .tint(.red)
            }
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
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if isLive {
                Button(role: .destructive) {
                    sessionManager.terminateSession(for: server.id)
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            }

            Button(role: .destructive) {
                deleteServer(server)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @State private var editingServer: ServerConnection?
    @State private var showEditSheet = false
    @State private var terminatingServer: ServerConnection?

    private func deleteServer(_ server: ServerConnection) {
        sessionManager.terminateSession(for: server.id)
        KeychainService.delete(for: server.id)
        modelContext.delete(server)
    }
}

extension ServerListView {
    @ViewBuilder
    private var editSheet: some View {
        if showEditSheet, let server = editingServer {
            ServerFormView(server: server)
        }
    }
}
