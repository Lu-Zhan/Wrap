import SwiftUI

struct SettingsView: View {
    @Environment(TerminalAppearance.self) private var appearance
    @Environment(\.dismiss) private var dismiss

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { appearance.backgroundColor },
            set: { appearance.backgroundColorHex = $0.toHex() }
        )
    }

    private var fgColorBinding: Binding<Color> {
        Binding(
            get: { appearance.foregroundColor },
            set: { appearance.foregroundColorHex = $0.toHex() }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("字体大小") {
                    HStack {
                        Slider(value: Bindable(appearance).fontSize, in: 10...24, step: 1)
                        Text("\(Int(appearance.fontSize)) pt")
                            .monospacedDigit()
                            .frame(minWidth: 48, alignment: .trailing)
                    }
                }

                Section("颜色") {
                    ColorPicker("背景色", selection: bgColorBinding, supportsOpacity: false)
                    ColorPicker("文字颜色", selection: fgColorBinding, supportsOpacity: false)
                }

                Section("预览") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(appearance.backgroundColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("user@server:~$ ls -la")
                                .foregroundStyle(appearance.foregroundColor)
                            Text("total 48")
                                .foregroundStyle(appearance.foregroundColor)
                            Text("drwxr-xr-x  12 user  staff   384 Mar  1 12:00 .")
                                .foregroundStyle(appearance.foregroundColor)
                            Text("drwxr-xr-x   5 user  staff   160 Feb 28 09:15 ..")
                                .foregroundStyle(appearance.foregroundColor)
                        }
                        .font(.system(size: appearance.fontSize, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    }
                    .frame(minHeight: 120)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }
            }
            .navigationTitle("终端外观")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
