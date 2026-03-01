import SwiftUI
import SwiftData

struct ServerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let server: ServerConnection?

    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var authMethod: AuthMethod = .password
    @State private var group = ""
    @State private var showPassword = false
    @State private var showDeleteAlert = false
    @State private var showNewGroupInput = false
    @State private var newGroupName = ""

    @Query private var allServers: [ServerConnection]

    private var isEditing: Bool { server != nil }

    private var existingGroups: [String] {
        let groups = Set(allServers.compactMap(\.group))
        return groups.sorted()
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !host.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    init(server: ServerConnection? = nil) {
        self.server = server
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                authSection
                organizationSection

                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "Edit Server" : "Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { loadExistingData() }
            .alert("Delete Server?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { deleteServer() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove \"\(name)\" and its saved credentials.")
            }
        }
    }

    private var serverSection: some View {
        Section("Server") {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)

            TextField("Host", text: $host)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Port", text: $port)
                .keyboardType(.numberPad)
        }
    }

    private var authSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $authMethod) {
                ForEach(AuthMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }

            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                if showPassword {
                    TextField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("Password", text: $password)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var organizationSection: some View {
        Section("Organization") {
            if existingGroups.isEmpty && !showNewGroupInput {
                Button("Add to Group...") {
                    showNewGroupInput = true
                }
            } else {
                Picker("Group", selection: $group) {
                    Text("None").tag("")
                    ForEach(existingGroups, id: \.self) { g in
                        Text(g).tag(g)
                    }
                    Text("New Group...").tag("__new__")
                }
                .onChange(of: group) { _, newValue in
                    if newValue == "__new__" {
                        showNewGroupInput = true
                        group = ""
                    }
                }
            }

            if showNewGroupInput {
                TextField("Group Name", text: $newGroupName)
                    .textInputAutocapitalization(.words)
                    .onSubmit {
                        if !newGroupName.isEmpty {
                            group = newGroupName
                            showNewGroupInput = false
                        }
                    }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Server", role: .destructive) {
                showDeleteAlert = true
            }
        }
    }

    private func loadExistingData() {
        guard let server else { return }
        name = server.name
        host = server.host
        port = String(server.port)
        username = server.username
        authMethod = server.authMethod
        group = server.group ?? ""
        password = KeychainService.load(for: server.id) ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        let portNumber = Int(port) ?? 22
        let serverGroup: String? = group.isEmpty ? nil : group

        if let server {
            server.name = trimmedName
            server.host = trimmedHost
            server.port = portNumber
            server.username = trimmedUsername
            server.authMethod = authMethod
            server.group = serverGroup
            try? KeychainService.save(credential: password, for: server.id)
        } else {
            let newServer = ServerConnection(
                name: trimmedName,
                host: trimmedHost,
                port: portNumber,
                username: trimmedUsername,
                authMethod: authMethod,
                group: serverGroup
            )
            modelContext.insert(newServer)
            try? KeychainService.save(credential: password, for: newServer.id)
        }

        dismiss()
    }

    private func deleteServer() {
        guard let server else { return }
        KeychainService.delete(for: server.id)
        modelContext.delete(server)
        dismiss()
    }
}
