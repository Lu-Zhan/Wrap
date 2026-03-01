import SwiftUI

struct TerminalSessionView: View {
    let server: ServerConnection
    let initialSession: TerminalSession?

    init(server: ServerConnection, session: TerminalSession? = nil) {
        self.server = server
        self.initialSession = session
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var sessionManager
    @Environment(TerminalAppearance.self) private var appearance
    @State private var currentSession: TerminalSession?
    @State private var showEditSheet = false
    @State private var wasConnected = false
    @State private var commandInput: String = ""

    var body: some View {
        let sshState = currentSession?.sshService.state ?? .disconnected

        ZStack {
            appearance.backgroundColor.ignoresSafeArea()

            switch sshState {
            case .disconnected:
                connectingOverlay
            case .connecting:
                connectingOverlay
            case .connected:
                if let session = currentSession {
                    terminalContent(session: session)
                        .ignoresSafeArea(edges: .top)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            inputBar(session)
                        }
                }
            case .failed(let message):
                failedContent(message: message)
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .overlay {
            if sshState == .disconnected && wasConnected {
                disconnectedOverlay
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ServerFormView(server: server)
        }
        .task {
            server.lastConnectedAt = Date()
            if let s = initialSession {
                currentSession = s
            } else {
                currentSession = await sessionManager.createNewSession(for: server)
            }
        }
    }

    @ViewBuilder
    private func statusDot(state: SSHService.ConnectionState) -> some View {
        switch state {
        case .connected:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .connecting:
            ProgressView().controlSize(.mini)
        case .failed:
            Circle().fill(.red).frame(width: 8, height: 8)
        case .disconnected:
            Circle().fill(.gray).frame(width: 8, height: 8)
        }
    }

    private func inputBar(_ session: TerminalSession) -> some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .frame(width: 36, height: 48)
                    .foregroundStyle(.primary)
            }

            TextField("输入命令后点击发送...", text: $commandInput)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
                .onSubmit { sendCommand(session: session) }

            Button(action: { sendCommand(session: session) }) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(commandInput.isEmpty ? .gray : .primary)
                    .frame(width: 36, height: 48)
            }
            .disabled(commandInput.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(appearance.backgroundColor)
    }

    private func sendCommand(session: TerminalSession) {
        guard !commandInput.isEmpty else { return }
        let text = commandInput + "\n"
        session.sshService.send(Data(text.utf8))
        commandInput = ""
    }

    private func terminalContent(session: TerminalSession) -> some View {
        TerminalRepresentable(session: session, appearance: appearance)
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
                Task {
                    if let s = currentSession {
                        await sessionManager.reconnect(s, for: server)
                    } else {
                        currentSession = await sessionManager.createNewSession(for: server)
                    }
                }
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
                    Task {
                        if let s = currentSession {
                            await sessionManager.reconnect(s, for: server)
                        } else {
                            currentSession = await sessionManager.createNewSession(for: server)
                        }
                    }
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
}
