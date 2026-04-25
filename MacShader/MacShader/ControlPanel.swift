import SwiftUI

struct ControlPanel: View {
    @ObservedObject var controller: OverlayWindowController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack {
                Text("CRT Shader")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $controller.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            Picker("Mode", selection: $controller.mode) {
                Text("Procedural").tag(UInt32(0))
                Text("Screen Capture").tag(UInt32(1))
            }
            .pickerStyle(.segmented)
            .disabled(!controller.isEnabled)

            if controller.mode == 1 {
                Text("Requires Screen Recording permission")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            SliderRow(label: "Scanlines",
                      value: $controller.scanlineIntensity,
                      disabled: !controller.isEnabled)

            SliderRow(label: "Glow",
                      value: $controller.glowIntensity,
                      disabled: !controller.isEnabled)

            SliderRow(label: "Saturation",
                      value: $controller.colorSaturation,
                      in: 1.0...3.0,
                      format: "%.1fx",
                      disabled: !controller.isEnabled)

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit MacShader", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(16)
        .frame(width: 280)
    }
}

private struct SliderRow: View {
    let label: String
    @Binding var value: Float
    var range: ClosedRange<Float> = 0...1
    var format: String = "%.0f%%"
    var disabled: Bool

    init(label: String, value: Binding<Float>, in range: ClosedRange<Float> = 0...1, format: String = "%.0f%%", disabled: Bool) {
        self.label = label
        self._value = value
        self.range = range
        self.format = format
        self.disabled = disabled
    }

    private var displayValue: String {
        if format.contains("x") {
            return String(format: format, value)
        }
        return String(format: format, value * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(displayValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range)
                .disabled(disabled)
        }
    }
}
