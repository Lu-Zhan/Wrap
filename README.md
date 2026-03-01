# Wrap

A native iOS SSH terminal client built with SwiftUI, SwiftTerm, and swift-nio-ssh.

## Features

- **One-tap connect** — tap a server to open a full terminal instantly
- **Full terminal emulation** — VT100/xterm-256color compatible, supports vim, htop, and other TUI apps
- **Secure credential storage** — passwords stored in iOS Keychain, never in plaintext
- **Server management** — add, edit, delete servers with custom groups and search
- **Reconnect on drop** — auto-prompts to reconnect when connection is lost
- **iOS 26 native UI** — Liquid Glass, NavigationStack, SwiftData, and more

## Tech Stack

| Component | Library |
|-----------|---------|
| Terminal emulator | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| SSH protocol | [swift-nio-ssh](https://github.com/apple/swift-nio-ssh) |
| Data persistence | SwiftData |
| Credential storage | iOS Keychain |
| UI | SwiftUI (iOS 26) |

## Requirements

- iOS 26+
- Xcode 26+

## Getting Started

1. Clone the repo
   ```bash
   git clone https://github.com/Lu-Zhan/Wrap.git
   ```
2. Open `Wrap.xcodeproj` in Xcode
3. Swift Package Manager will resolve dependencies automatically
4. Build and run on a device or simulator

## Project Structure

```
Wrap/
├── Models/
│   ├── ServerConnection.swift   # SwiftData model for server info
│   └── AuthMethod.swift         # Authentication method enum
├── Services/
│   ├── KeychainService.swift    # Keychain read/write/delete
│   ├── SSHService.swift         # SSH session lifecycle
│   └── SSHChannelHandler.swift  # NIO channel data handler
└── Views/
    ├── ServerListView.swift      # Main screen — grouped server list
    ├── ServerFormView.swift      # Add / edit server form
    ├── TerminalSessionView.swift # Full-screen terminal session
    └── TerminalRepresentable.swift # SwiftTerm UIViewRepresentable bridge
```

## Roadmap

- [ ] Private key authentication (RSA, Ed25519, ECDSA)
- [ ] Host key verification / known hosts
- [ ] Multiple sessions with tab switching
- [ ] SFTP file browser
- [ ] Port forwarding
- [ ] iCloud sync
- [ ] Mosh support
- [ ] iPad split-screen terminal
- [ ] Biometric lock

## License

MIT
