import SwiftUI
import Carbon
import AppKit

struct HotkeyRecorderRow: View {
    let label: String
    let icon: String
    let accent: Color
    let config: HotkeyConfig
    let conflictLabel: String?
    let onUpdate: (HotkeyConfig) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var hasConflict: Bool { conflictLabel != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(hasConflict ? Color.orange : accent)
                    .frame(width: 18)

                Text(label)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if !config.isNone {
                    Button {
                        stopRecording()
                        onUpdate(.none)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if isRecording { stopRecording() } else { startRecording() }
                } label: {
                    HStack(spacing: 5) {
                        if hasConflict && !isRecording {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        Text(isRecording ? "Taste drücken…"
                             : config.isNone ? "Kein Shortcut"
                             : config.displayString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(
                                isRecording ? .white
                                : hasConflict ? Color.orange
                                : config.isNone ? Color.secondary
                                : Color.primary
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        isRecording
                            ? AnyShapeStyle(accent)
                            : hasConflict
                                ? AnyShapeStyle(Color.orange.opacity(0.12))
                                : AnyShapeStyle(Color.primary.opacity(0.07)),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                isRecording ? accent
                                : hasConflict ? Color.orange.opacity(0.6)
                                : Color.primary.opacity(0.13),
                                lineWidth: 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: isRecording)
                    .animation(.easeInOut(duration: 0.2), value: hasConflict)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, hasConflict ? 4 : 10)

            if let conflict = conflictLabel {
                Text("Bereits vergeben für \"\(conflict)\"")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .padding(.leading, 46)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasConflict)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let mods = HotkeyConfig.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { stopRecording(); return event }
            onUpdate(HotkeyConfig(keyCode: Int(event.keyCode), modifiers: mods))
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }
}
