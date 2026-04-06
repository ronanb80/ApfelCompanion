import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        Form {
            Section("System Prompt") {
                TextEditor(text: $viewModel.settings.systemPrompt)
                    .font(.body)
                    .frame(minHeight: 80)
                    .accessibilityIdentifier("settings.systemPrompt")
                    .onChange(of: viewModel.settings.systemPrompt) {
                        viewModel.saveSettings()
                    }

                Text("Applied to all chats as a system message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model Parameters") {
                temperatureControl
                maxTokensControl
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 350)
    }

    private var temperatureControl: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: Binding(
                get: { viewModel.settings.temperature != nil },
                set: { enabled in
                    viewModel.settings.temperature = enabled ? 1.0 : nil
                    viewModel.saveSettings()
                }
            )) {
                Text("Temperature")
            }
            .accessibilityIdentifier("settings.temperature.toggle")

            if let temperature = viewModel.settings.temperature {
                HStack {
                    Slider(
                        value: Binding(
                            get: { temperature },
                            set: { newValue in
                                viewModel.settings.temperature = newValue
                                viewModel.saveSettings()
                            }
                        ),
                        in: 0.0...2.0,
                        step: 0.1
                    )
                    .accessibilityIdentifier("settings.temperature.slider")
                    Text(String(format: "%.1f", temperature))
                        .monospacedDigit()
                        .accessibilityIdentifier("settings.temperature.value")
                        .frame(width: 40)
                }
            }
        }
    }

    private var maxTokensControl: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: Binding(
                get: { viewModel.settings.maxTokens != nil },
                set: { enabled in
                    viewModel.settings.maxTokens = enabled ? 2048 : nil
                    viewModel.saveSettings()
                }
            )) {
                Text("Max Tokens")
            }
            .accessibilityIdentifier("settings.maxTokens.toggle")

            if let maxTokens = viewModel.settings.maxTokens {
                HStack {
                    TextField(
                        "Tokens",
                        value: Binding(
                            get: { maxTokens },
                            set: { newValue in
                                viewModel.settings.maxTokens = newValue
                                viewModel.saveSettings()
                            }
                        ),
                        format: .number
                    )
                    .accessibilityIdentifier("settings.maxTokens.field")
                    .frame(width: 100)

                    Text("tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
