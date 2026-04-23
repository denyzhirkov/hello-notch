import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var displaySeconds: Double = Config.autoHideSeconds
    @State private var keepUntilClicked: Bool = Config.keepUntilClicked
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            VStack(spacing: 16) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .onChange(of: launchAtLogin) {
                        do {
                            if launchAtLogin {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Display duration")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(keepUntilClicked ? 0.4 : 0.85))
                        Spacer()
                        Text(keepUntilClicked ? "until clicked" : "\(Int(displaySeconds))s")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(.white.opacity(keepUntilClicked ? 0.35 : 0.5))
                    }

                    Slider(
                        value: $displaySeconds,
                        in: Config.autoHideMinSeconds...Config.autoHideMaxSeconds,
                        step: Config.autoHideStep
                    )
                    .disabled(keepUntilClicked)
                    .opacity(keepUntilClicked ? 0.4 : 1)
                    .onChange(of: displaySeconds) {
                        UserDefaults.standard.set(displaySeconds, forKey: "autoHideSeconds")
                    }

                    Toggle("Keep visible until clicked", isOn: $keepUntilClicked)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .onChange(of: keepUntilClicked) {
                            UserDefaults.standard.set(keepUntilClicked, forKey: "keepUntilClicked")
                        }
                }

                Spacer()

                HStack {
                    Spacer()
                    Button("Close") { onClose() }
                        .buttonStyle(FlatButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 360, height: 280)
        .background(VisualEffectBlur())
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Panel presenter

@MainActor
func showSettingsPanel() {
    let panel = makeFlatPanel(width: 360, height: 280)

    let hostingView = NSHostingView(
        rootView: SettingsView(onClose: { panel.close() })
    )

    panel.contentView = hostingView
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
