import Foundation
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOSSH

@Observable
final class SSHService {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    var state: ConnectionState = .disconnected

    private var group: MultiThreadedEventLoopGroup?
    private var parentChannel: Channel?
    private var shellChannel: Channel?

    var onData: (([UInt8]) -> Void)?

    func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        initialCols: Int = 80,
        initialRows: Int = 24
    ) async {
        state = .connecting

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        do {
            let authDelegate = PasswordAuthDelegate(username: username, password: password)
            let hostKeyDelegate = AcceptAllHostKeysDelegate()

            nonisolated(unsafe) let clientConfig = SSHClientConfiguration(
                userAuthDelegate: authDelegate,
                serverAuthDelegate: hostKeyDelegate
            )

            // Strong capture of self; cycle broken in disconnect()
            let service = self
            let shellHandler = SSHShellHandler(
                onData: { bytes in
                    Task { @MainActor in
                        service.onData?(bytes)
                    }
                },
                onClose: {
                    Task { @MainActor in
                        if service.state == .connected {
                            service.state = .disconnected
                        }
                    }
                }
            )

            let bootstrap = ClientBootstrap(group: group)
                .channelInitializer { channel in
                    channel.pipeline.addHandler(
                        NIOSSHHandler(
                            role: .client(clientConfig),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                }
                .channelOption(.socketOption(.so_reuseaddr), value: 1)
                .connectTimeout(.seconds(10))

            let channel = try await bootstrap.connect(host: host, port: port).get()
            self.parentChannel = channel

            // Chain futures on event loop so NIOSSHHandler never crosses async boundary
            let childChannel = try await channel.pipeline.handler(type: NIOSSHHandler.self)
                .flatMap { sshHandler -> EventLoopFuture<Channel> in
                    let promise = channel.eventLoop.makePromise(of: Channel.self)
                    sshHandler.createChannel(promise, channelType: .session) { childChannel, channelType in
                        guard channelType == .session else {
                            return childChannel.eventLoop.makeFailedFuture(SSHServiceError.unsupportedChannelType)
                        }
                        return childChannel.pipeline.addHandler(shellHandler)
                    }
                    return promise.futureResult
                }.get()

            self.shellChannel = childChannel

            let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: initialCols,
                terminalRowHeight: initialRows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: SSHTerminalModes([:])
            )
            try await childChannel.triggerUserOutboundEvent(ptyRequest).get()

            let shellRequest = SSHChannelRequestEvent.ShellRequest(wantReply: true)
            try await childChannel.triggerUserOutboundEvent(shellRequest).get()

            state = .connected
        } catch {
            state = .failed(error.localizedDescription)
            try? await group.shutdownGracefully()
            self.group = nil
        }
    }

    func send(_ data: Data) {
        guard let shellChannel else { return }
        var buffer = shellChannel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        shellChannel.writeAndFlush(buffer, promise: nil)
    }

    func sendWindowChange(cols: Int, rows: Int) {
        guard let shellChannel else { return }
        let request = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        shellChannel.triggerUserOutboundEvent(request, promise: nil)
    }

    func disconnect() {
        shellChannel?.close(promise: nil)
        parentChannel?.close(promise: nil)
        state = .disconnected

        let group = self.group
        self.group = nil
        self.shellChannel = nil
        self.parentChannel = nil

        Task.detached {
            try? await group?.shutdownGracefully()
        }
    }
}
