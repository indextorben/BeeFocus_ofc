import SwiftUI
import Carbon
import AppKit

struct HotkeyRecorderRow: View {
    let label: String
    let icon: String
    let accent: Color
    @Binding var config: HotkeyConfig

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(accent)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            // Clear button
            if !config.isNone {
                Button {
                    stopRecording()
                    config = .none
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Recorder pill
            Button {
                if isRecording { stopRecording() } else { startRecording() }
            } label: {
                Text(isRecording ? "Taste drücken…" : (config.isNone ? "Kein Shortcut" : config.displayString))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRecording ? .white : (config.isNone ? Color.secondary : Color.primary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        isRecording
                            ? AnyShapeStyle(accent)
                            : AnyShapeStyle(Color.primary.opacity(0.07)),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                isRecording ? accent : Color.primary.opacity(0.13),
                                lineWidth: 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: isRecording)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onDisappear { stopRecording() }
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        // Local monitor — fires for key events while panel is key window
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let mods = HotkeyConfig.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else {
                // No modifier held — ignore plain keys
                stopRecording()
                return event
            }
            config = HotkeyConfig(keyCode: Int(event.keyCode), modifiers: mods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }
}
