import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

struct InputBarView: View {
    @Binding var text: String
    let isGenerating: Bool
    let isServerReady: Bool
    let attachments: [PendingAttachment]
    let onSend: () -> Void
    let onStop: () -> Void
    let onAddAttachments: ([URL]) -> Void
    let onRemoveAttachment: (UUID) -> Void

    @State private var textHeight: CGFloat = Self.minEditorHeight
    @State private var isShowingFilePicker = false

    static let minEditorHeight: CGFloat = 24
    static let maxEditorHeight: CGFloat = 120
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachments) { attachment in
                            AttachmentChip(
                                fileName: attachment.fileName,
                                onRemove: { onRemoveAttachment(attachment.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }

            HStack(spacing: 8) {
                Button(action: { isShowingFilePicker = true }) {
                    Image(systemName: "paperclip")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!isServerReady)
                .accessibilityLabel("Attach File")
                .accessibilityIdentifier("chat.attach")

                composer

                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Stop Generation")
                    .accessibilityIdentifier("chat.stop")
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .disabled(!canSend)
                    .accessibilityLabel("Send Message")
                    .accessibilityIdentifier("chat.send")
                }
            }
            .padding(12)
        }
        .background(.bar)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.plainText, .sourceCode, .json, .xml, .yaml, .pdf],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                onAddAttachments(urls)
            }
        }
    }

    private var composer: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Type a message...")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Self.horizontalPadding)
                    .padding(.vertical, Self.verticalPadding)
                    .allowsHitTesting(false)
            }

            AutoGrowingTextView(
                text: $text,
                measuredHeight: $textHeight,
                isEnabled: isServerReady,
                onSend: {
                    if canSend {
                        onSend()
                    }
                }
            )
            .frame(height: min(max(textHeight, Self.minEditorHeight), Self.maxEditorHeight))
            .accessibilityLabel("Message Input")
            .accessibilityIdentifier("chat.input")
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isServerReady
    }
}

#if canImport(AppKit)
private struct AutoGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    let isEnabled: Bool
    let onSend: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, measuredHeight: $measuredHeight, onSend: onSend)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EnterInterceptingTextView()
        textView.delegate = context.coordinator
        textView.onPlainReturn = onSend
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(
            width: InputBarView.horizontalPadding - 6,
            height: InputBarView.verticalPadding
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: InputBarView.minEditorHeight)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.setAccessibilityLabel("Message Input")
        textView.setAccessibilityIdentifier("chat.input")

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EnterInterceptingTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.isEditable = isEnabled
        textView.onPlainReturn = onSend
        context.coordinator.recalculateHeight(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var measuredHeight: CGFloat

        weak var textView: NSTextView?
        private let onSend: () -> Void

        init(text: Binding<String>, measuredHeight: Binding<CGFloat>, onSend: @escaping () -> Void) {
            _text = text
            _measuredHeight = measuredHeight
            self.onSend = onSend
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            recalculateHeight(for: textView)
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)

            let usedRect = layoutManager.usedRect(for: textContainer)
            let nextHeight = max(
                ceil(usedRect.height + (textView.textContainerInset.height * 2)),
                InputBarView.minEditorHeight
            )

            if abs(measuredHeight - nextHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.measuredHeight = nextHeight
                }
            }
        }
    }
}

private final class EnterInterceptingTextView: NSTextView {
    var onPlainReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) {
                super.keyDown(with: event)
            } else {
                onPlainReturn?()
            }
            return
        }

        super.keyDown(with: event)
    }
}
#endif
private struct AttachmentChip: View {
    let fileName: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.caption)
            Text(fileName)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(8)
    }
}
