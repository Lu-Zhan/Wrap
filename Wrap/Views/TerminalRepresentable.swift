import SwiftUI
import SwiftTerm

struct TerminalRepresentable: UIViewRepresentable {
    let session: TerminalSession
    let appearance: TerminalAppearance

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.contentInsetAdjustmentBehavior = .automatic
        applyAppearance(terminalView)
        context.coordinator.terminalView = terminalView

        // Double-path onData: write to scrollback + feed terminal
        session.sshService.onData = { [weak terminalView] bytes in
            session.appendToScrollback(bytes)
            terminalView?.feed(byteArray: bytes[...])
        }

        // 新会话：根据 toolbar 底线高度动态计算换行数，使首行提示符出现在 toolbar 下方
        if session.scrollbackData.isEmpty {
            let safeTop = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .windows.first?.safeAreaInsets.top ?? 47
            let toolbarBottom = safeTop + 44 // status bar + navigation bar
            let font = UIFont.monospacedSystemFont(ofSize: appearance.fontSize, weight: .regular)
            let lineCount = max(1, Int(ceil(toolbarBottom / font.lineHeight)))
            let padding: [UInt8] = Array(String(repeating: "\r\n", count: lineCount).utf8)
            terminalView.feed(byteArray: padding[...])
        }

        // Replay historical scrollback asynchronously in 64KB chunks
        let snapshot = session.scrollbackData
        if !snapshot.isEmpty {
            Task { @MainActor in
                let chunkSize = 65_536
                var start = 0
                while start < snapshot.count {
                    let end = min(start + chunkSize, snapshot.count)
                    terminalView.feed(byteArray: snapshot[start..<end])
                    start = end
                    if start < snapshot.count {
                        await Task.yield()
                    }
                }
            }
        }

        DispatchQueue.main.async {
            terminalView.becomeFirstResponder()
        }

        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        applyAppearance(uiView)
    }

    private func applyAppearance(_ terminalView: TerminalView) {
        terminalView.font = UIFont.monospacedSystemFont(ofSize: appearance.fontSize, weight: .regular)
        terminalView.nativeBackgroundColor = UIColor(appearance.backgroundColor)
        terminalView.nativeForegroundColor = UIColor(appearance.foregroundColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        let session: TerminalSession
        weak var terminalView: TerminalView?

        init(session: TerminalSession) {
            self.session = session
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            session.sshService.send(Data(data))
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            session.lastKnownCols = newCols
            session.lastKnownRows = newRows
            session.sshService.sendWindowChange(cols: newCols, rows: newRows)
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
