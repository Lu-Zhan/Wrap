@preconcurrency import NIOCore
@preconcurrency import NIOSSH

nonisolated final class SSHShellHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private let onData: @Sendable ([UInt8]) -> Void
    private let onClose: @Sendable () -> Void

    nonisolated init(onData: @escaping @Sendable ([UInt8]) -> Void, onClose: @escaping @Sendable () -> Void) {
        self.onData = onData
        self.onClose = onClose
    }

    nonisolated func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        guard case .byteBuffer(var buffer) = channelData.data else { return }
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        onData(bytes)
    }

    nonisolated func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let channelData = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        context.write(wrapOutboundOut(channelData), promise: promise)
    }

    nonisolated func channelInactive(context: ChannelHandlerContext) {
        onClose()
        context.fireChannelInactive()
    }

    nonisolated func errorCaught(context: ChannelHandlerContext, error: Error) {
        onClose()
        context.close(promise: nil)
    }
}

nonisolated final class PasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate, Sendable {
    let username: String
    let password: String

    nonisolated init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    nonisolated func nextAuthenticationType(
        availableMethods availableAuthenticationMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        if availableAuthenticationMethods.contains(.password) {
            nextChallengePromise.succeed(
                NIOSSHUserAuthenticationOffer(
                    username: username,
                    serviceName: "",
                    offer: .password(.init(password: password))
                )
            )
        } else {
            nextChallengePromise.succeed(nil)
        }
    }
}

nonisolated final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate, Sendable {
    nonisolated func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        validationCompletePromise.succeed(())
    }
}

enum SSHServiceError: Error {
    case unsupportedChannelType
    case connectionFailed
}
