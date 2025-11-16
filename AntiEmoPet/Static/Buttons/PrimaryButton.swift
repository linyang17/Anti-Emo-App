import SwiftUI
import UIKit


struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}



struct NavigationGestureDisabler: UIViewControllerRepresentable {
	let isDisabled: Bool

	func makeUIViewController(context: Context) -> Controller {
		Controller(isDisabled: isDisabled)
	}

	func updateUIViewController(_ controller: Controller, context: Context) {
		controller.isDisabled = isDisabled
	}

	final class Controller: UIViewController {
		var isDisabled: Bool {
			didSet { updateInteractivePopState() }
		}

		init(isDisabled: Bool) {
			self.isDisabled = isDisabled
			super.init(nibName: nil, bundle: nil)
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

		override func viewWillAppear(_ animated: Bool) {
			super.viewWillAppear(animated)
			updateInteractivePopState()
		}

		override func viewDidDisappear(_ animated: Bool) {
			super.viewDidDisappear(animated)
			navigationController?.interactivePopGestureRecognizer?.isEnabled = true
		}

		private func updateInteractivePopState() {
			navigationController?.interactivePopGestureRecognizer?.isEnabled = !isDisabled
		}
	}
}
