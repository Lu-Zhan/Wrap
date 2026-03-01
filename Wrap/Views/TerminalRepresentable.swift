import SwiftUI
import SwiftTerm

struct TerminalRepresentable: UIViewRepresentable {
    let sshService: SSHService

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .white
        context.coordinator.terminalView = terminalView

        sshService.onData = { [weak terminalView] bytes in
            terminalView?.feed(byteArray: bytes[...])
        }

        DispatchQueue.main.async {
            terminalView.becomeFirstResponder()
        }

        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(sshService: sshService)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        let sshService: SSHService
        weak var terminalView: TerminalView?

        init(sshService: SSHService) {
            self.sshService = sshService
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            sshService.send(Data(data))
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            sshService.sendWindowChange(cols: newCols, rows: newRows)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            if let url = URL(string: link) {
                UIApplication.shared.open(url)
            }
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
        }

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    }
}
