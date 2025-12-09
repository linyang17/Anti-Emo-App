import SwiftUI
import UIKit

struct GrowingTextView: UIViewRepresentable {
        @Binding var text: String
        @Binding var calculatedHeight: CGFloat
        @Binding var isFocused: Bool

        let maxHeight: CGFloat
        var onReturn: (() -> Void)? = nil

        func makeUIView(context: Context) -> UITextView {
                let view = UITextView()
                view.delegate = context.coordinator
                view.isScrollEnabled = false
                view.backgroundColor = .clear
                view.font = UIFont.preferredFont(forTextStyle: .body)
                view.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
                view.text = text
                view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                return view
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
                if uiView.text != text {
                        uiView.text = text
                }

                if isFocused && !uiView.isFirstResponder {
                        uiView.becomeFirstResponder()
                } else if !isFocused && uiView.isFirstResponder {
                        uiView.resignFirstResponder()
                }

                DispatchQueue.main.async {
                        updateHeight(for: uiView)
                }
        }

        func makeCoordinator() -> Coordinator {
                Coordinator(parent: self)
        }

        private func updateHeight(for view: UITextView) {
                // Ensure we always measure with a sensible width (avoid 0 before layout)
                let availableWidth = max(view.bounds.width, UIScreen.main.bounds.width * 0.6)
                let targetSize = CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
                let size = view.sizeThatFits(targetSize)
                let newHeight = min(maxHeight, size.height)
                if calculatedHeight != newHeight {
                        calculatedHeight = newHeight
                }
                view.isScrollEnabled = size.height > maxHeight
        }

        final class Coordinator: NSObject, UITextViewDelegate {
                var parent: GrowingTextView

                init(parent: GrowingTextView) {
                        self.parent = parent
                }

                func textViewDidChange(_ textView: UITextView) {
                        parent.text = textView.text
                        parent.updateHeight(for: textView)
                }

                func textViewDidBeginEditing(_ textView: UITextView) {
                        parent.isFocused = true
                }

                func textViewDidEndEditing(_ textView: UITextView) {
                        parent.isFocused = false
                }

                func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
                        if text == "\n", let onReturn = parent.onReturn {
                                onReturn()
                                return false
                        }
                        return true
                }
        }
}
