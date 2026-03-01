import SwiftUI

struct TerminalSessionView: View {
    let server: ServerConnection
    @Environment(\.dismiss) private var dismiss
    @State private var sshService = SSHService()
    @State private var showDisconnectAlert = false
    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch sshService.state {
            case .disconnected:
                connectingOverlay
            case .connecting:
                connectingOverlay
            case .connected:
                terminalContent
            case .failed(let message):
                failedContent(message: message)
            }
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            statusBar
        }
        .overlay {
            if sshService.state == .disconnected && wasConnected {
                disconnectedOverlay
            }
        }
        .alert("Disconnect from \(server.name)?", isPresented: $showDisconnectAlert) {
            Button("Disconnect", role: .destructive) {
                sshService.disconnect()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            ServerFormView(server: server)
        }
        .task {
            await connectToServer()
        }
    }

    @State private var wasConnected = false

    private var statusBar: some View {
        HStack {
            Button {
                if sshService.state == .connected {
                    showDisconnectAlert = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }

            Spacer()

            Text(server.name)
                .font(.subheadline.weight(.medium))

            Spacer()

            statusIndicator
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch sshService.state {
        case .connected:
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Connected").font(.caption2)
            }
        case .connecting:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Connecting...").font(.caption2)
            }
        case .failed:
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("Failed").font(.caption2)
            }
        case .disconnected:
            HStack(spacing: 4) {
                Circle().fill(.gray).frame(width: 8, height: 8)
                Text("Disconnected").font(.caption2)
            }
        }
    }

    private var terminalContent: some View {
        TerminalRepresentable(sshService: sshService)
            .padding(.top, 44)
            .onAppear {
                wasConnected = true
            }
    }

    private var connectingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(server.host)...")
                .foregroundStyle(.secondary)
        }
    }

    private func failedContent(message: String) -> some View {
        ContentUnavailableView {
            Label("Connection Failed", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Could not connect to \(server.host):\(server.port)\n\n\(message)")
        } actions: {
            Button("Retry") {
                Task { await connectToServer() }
            }
            .buttonStyle(.borderedProminent)

            Button("Edit Server") {
                showEditSheet = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var disconnectedOverlay: some View {
        VStack(spacing: 16) {
            Text("Connection Lost")
                .font(.headline)
            HStack(spacing: 12) {
                Button("Reconnect") {
                    Task { await connectToServer() }
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func connectToServer() async {
        guard let password = KeychainService.load(for: server.id) else {
            sshService.state = .failed("No credentials found. Please edit this server.")
            return
        }

        server.lastConnectedAt = Date()

        await sshService.connect(
            host: server.host,
            port: server.port,
            username: server.username,
            password: password
        )
    }
}
