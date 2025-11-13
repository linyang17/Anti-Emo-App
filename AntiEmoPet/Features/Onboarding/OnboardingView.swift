import SwiftUI
import UIKit
import CoreLocation

struct OnboardingView: View {
	@StateObject private var viewModel = OnboardingViewModel()
	@EnvironmentObject private var appModel: AppViewModel
	@ObservedObject private var locationService: LocationService
	@Environment(\.openURL) private var openURL
	@FocusState private var isNameFocused: Bool
	@State private var step: Step = .intro
	@State private var isProcessingFinalStep = false
	@State private var showLocationDeniedAlert = false
	@State private var hasCompletedOnboarding = false
	@State private var dragOffset: CGFloat = .zero
	@State private var hasTriggeredHapticPreview = false

	init(locationService: LocationService? = nil) {
		_locationService = ObservedObject(wrappedValue: locationService ?? LocationService())
	}

	var body: some View {
		ZStack {
			Image("bg-main")
				.resizable()
				.scaledToFill()
				.ignoresSafeArea()

			VStack {

				VStack(spacing: 24) {
					stepContent
						.transition(.opacity)
						.animation(.easeInOut, value: step)

					if step != .celebration {
						OnboardingArrowButton(
							isEnabled: canAdvance,
							isLoading: isProcessingFinalStep,
							action: handleAdvance
						)
					}
				}
					.frame(maxWidth: .infinity)
					.padding(.top, 120)
					.padding(.bottom, 120)
					.offset(x: dragOffset)
					.gesture(backSwipeGesture)
				
				Spacer(minLength: 50)
				}

			if step != .celebration {
				VStack {
					Spacer()
					Image("foxcurious")
						.resizable()
						.scaledToFit()
						.frame(maxWidth: 220)
						.accessibilityHidden(true)
						.padding(.top, 120)
						.padding(.bottom, 120)
				}
			}
		}
		.alert("无法获取定位", isPresented: $showLocationDeniedAlert) {
			Button("前往设置") {
				isProcessingFinalStep = true
				if let url = URL(string: UIApplication.openSettingsURLString) {
					openURL(url)
				}
			}
		} message: {
			Text("后续任务将无法根据你当前城市的天气情况生成")
		}
		.onChange(of: locationService.authorizationStatus) { oldValue, newValue in
			handleLocationAuthorizationChange(newValue)
		}
		.onChange(of: locationService.lastKnownCity) { _, newCity in
			if !newCity.isEmpty {
				viewModel.region = newCity
			}
		}
		.onChange(of: locationService.weatherPermissionGranted) { _, granted in
			viewModel.setWeatherPermission(granted)
		}
		.task {
			viewModel.updateLocationStatus(locationService.authorizationStatus)
			if !locationService.lastKnownCity.isEmpty {
				viewModel.region = locationService.lastKnownCity
			}
			viewModel.setWeatherPermission(locationService.weatherPermissionGranted)
		}
		.onChange(of: step) { _, newStep in
			if newStep == .access {
				viewModel.updateLocationStatus(locationService.authorizationStatus)
			}
		}
		.background(NavigationGestureDisabler(isDisabled: true))
	}
}

private extension OnboardingView {
	enum Step: Int, CaseIterable {
		case intro
		case name
		case gender
		case birthday
		case access
		case celebration

		var next: Step? {
			Step(rawValue: rawValue + 1)
		}

		var previous: Step? {
			Step(rawValue: rawValue - 1)
		}
	}

	@ViewBuilder
	var stepContent: some View {
		switch step {
		case .intro:
			IntroStepView()
		case .name:
			NameStepView(
				nickname: $viewModel.nickname,
				focus: $isNameFocused,
				onSubmit: handleAdvance
			)
		case .gender:
			GenderStepView(selectedGender: $viewModel.selectedGender)
		case .birthday:
			BirthdayStepView(selectedDate: $viewModel.birthday)
		case .access:
			AccessStepView()
		case .celebration:
			FoxWaveStepView {
					finishOnboarding(shareLocation: true)
					}
		}
	}

	var canAdvance: Bool {
		switch step {
		case .intro:
			return true
		case .name:
			return !viewModel.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		case .gender:
			return viewModel.selectedGender != nil
		case .birthday:
			let birthday = viewModel.birthday
			return birthday <= Date()
		case .access:
			return !isProcessingFinalStep
		case .celebration:
			return false
		}
	}

	func handleAdvance() {
		guard canAdvance else { return }
		switch step {
		case .access:
			let status = locationService.authorizationStatus
			switch status {
			case .authorizedAlways, .authorizedWhenInUse:
				// 已经有权限：第二次点击，真正执行最终流程并进入宠物页面
				viewModel.enableLocationAndWeather = true
				isProcessingFinalStep = false
				locationService.requestLocationOnce()
				requestWeatherAndNotifications()
			case .denied, .restricted:
				// 权限被拒绝或受限，提示用户去设置
				viewModel.enableLocationAndWeather = false
				isProcessingFinalStep = false
				showLocationDeniedAlert = true
			case .notDetermined:
				// 第一次/尚未决定：只请求权限，等待系统弹窗结果
				isProcessingFinalStep = true
				locationService.requestLocAuthorization()
			@unknown default:
				isProcessingFinalStep = true
				locationService.requestLocAuthorization()
			}
			return
		default:
			if let next = step.next {
				withAnimation(.easeInOut) {
					step = next
				}
				if next == .name {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						isNameFocused = true
					}
				} else {
					isNameFocused = false
				}
			}
		}
	}

	func handleRetreat() {
		guard let previous = step.previous else { return }
		let generator = UIImpactFeedbackGenerator(style: .medium)
		generator.impactOccurred()
		withAnimation(.spring(response: 0.32, dampingFraction: 0.78, blendDuration: 0.1)) {
			step = previous
		}
		isProcessingFinalStep = false
		if previous == .name {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
				isNameFocused = true
			}
		} else {
			isNameFocused = false
		}
	}


	func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus) {
		viewModel.updateLocationStatus(status)
		guard step == .access else { return }
		switch status {
		case .authorizedAlways, .authorizedWhenInUse:
			// 用户在系统弹窗中授予了权限：结束 loading，保持在 access 页面，等待用户再次点击箭头进入下一步
			isProcessingFinalStep = false
			// 不在这里自动请求天气和结束 Onboarding
		case .denied, .restricted:
			// 用户拒绝/受限：关闭 loading，提示去设置
			viewModel.enableLocationAndWeather = false
			isProcessingFinalStep = false
			showLocationDeniedAlert = true
		case .notDetermined:
			isProcessingFinalStep = false
		@unknown default:
			break
		}
	}

	func requestWeatherAndNotifications() {
		guard !hasCompletedOnboarding else { return }

		if viewModel.hasWeatherPermission {
			if viewModel.notificationsOptIn {
				appModel.requestNotifications()
			}
			isProcessingFinalStep = false
			withAnimation(.easeInOut) {
				step = .celebration
			}
			return
		}

		Task { @MainActor in
			let granted = await appModel.requestWeatherAccess()
			viewModel.setWeatherPermission(granted)
			if granted {
				locationService.updateWeatherPermission(granted: true)
				if viewModel.notificationsOptIn {
					appModel.requestNotifications()
				}
				isProcessingFinalStep = false
				withAnimation(.easeInOut) {
					step = .celebration
				}
			} else {
				locationService.updateWeatherPermission(granted: false)
				viewModel.enableLocationAndWeather = false
				isProcessingFinalStep = false
				showLocationDeniedAlert = true
			}
		}
	}

	func finishOnboarding(shareLocation: Bool) {
		guard !hasCompletedOnboarding else { return }
		isProcessingFinalStep = false
		isNameFocused = false

		// 预处理用户输入，去掉首尾空格
		let trimmedName = viewModel.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedRegion = viewModel.region.trimmingCharacters(in: .whitespacesAndNewlines)
		let genderRaw = viewModel.selectedGender?.rawValue ?? GenderIdentity.unspecified.rawValue

		viewModel.enableLocationAndWeather = shareLocation

		appModel.updateProfile(
			nickname: trimmedName,
			region: trimmedRegion,
			shareLocation: shareLocation,
			gender: genderRaw,
			birthday: viewModel.birthday,
			Onboard: true
		)
		hasCompletedOnboarding = true
	}

	var backSwipeGesture: some Gesture {
		DragGesture(minimumDistance: 20, coordinateSpace: .local)
			.onChanged { value in
				guard value.translation.width > 0 else {
					dragOffset = 0
					hasTriggeredHapticPreview = false
					return
				}
				dragOffset = min(value.translation.width, 160)
				if !hasTriggeredHapticPreview, dragOffset > 40, step.previous != nil {
					let generator = UIImpactFeedbackGenerator(style: .soft)
					generator.impactOccurred()
					hasTriggeredHapticPreview = true
				}
			}
			.onEnded { value in
				defer {
					withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
						dragOffset = 0
					}
					hasTriggeredHapticPreview = false
				}
				guard value.translation.width > 90 else { return }
				handleRetreat()
			}
	}
}


struct LumioSay: View {
	let text: String

	var body: some View {
		Text(text)
			.font(.system(.title2, design: .rounded).weight(.semibold))
			.multilineTextAlignment(.center)
			.foregroundStyle(.white)
			.shadow(color: .gray.opacity(0.25), radius: 4, x: 1, y: 1)
			.shadow(color: .cyan.opacity(0.1), radius: 2, x: 1, y: 1)
	}
}


private struct IntroStepView: View {
	var body: some View {
		LumioSay(text: "Hey! I'm Lumio, \n another fox from \n the little prince's planet.")
	}
}

private struct NameStepView: View {
	@Binding var nickname: String
	let focus: FocusState<Bool>.Binding
	let onSubmit: () -> Void

	var body: some View {
		VStack(spacing: 24) {
			LumioSay(text: "My lovely new friend, \n what shall I call you?")

			TextField("Type here…", text: $nickname)
				.frame(width: 200, height: 40)
				.padding(.vertical, 14)
				.padding(.horizontal, 18)
				.background(
					RoundedRectangle(cornerRadius: 18, style: .continuous)
						.stroke(Color.white.opacity(0.6), lineWidth: 1)
						.background(
							RoundedRectangle(cornerRadius: 18, style: .continuous)
								.fill(Color.white.opacity(0.15))
						)
				)
				.foregroundStyle(.white)
				.tint(.white)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.words)
				.submitLabel(.done)
				.focused(focus)
				.onSubmit(onSubmit)
		}
	}
}

private struct GenderStepView: View {
	@Binding var selectedGender: OnboardingViewModel.GenderOption?

	private let genderOptions = OnboardingViewModel.GenderOption.allCases

	var body: some View {
		VStack(spacing: 24) {
			LumioSay(text: "And you are…")

			HStack(spacing: 16) {
				ForEach(genderOptions) { option in
					Button {
						selectedGender = option
					} label: {
						Text(option.displayName)
							.font(.system(size: 15, weight: .medium, design: .rounded))
							.frame(width: 70, height: 40)
							.background(
								RoundedRectangle(cornerRadius: 18, style: .continuous)
									.fill(backgroundColor(for: option))
							).overlay(
								RoundedRectangle(cornerRadius: 18, style: .continuous)
									.stroke(Color.white.opacity(0.9), lineWidth: option == selectedGender ? 1.5 : 0.8)
							)
							.foregroundStyle(.white)
					}
					.buttonStyle(.plain)
				}
			}
		}
	}

	private func backgroundColor(for option: OnboardingViewModel.GenderOption) -> Color {
		option == selectedGender ? Color.black.opacity(0.2) : Color.white.opacity(0.12)
	}
}

private struct BirthdayStepView: View {
	@Binding var selectedDate: Date

	var body: some View {
		VStack(spacing: 24) {
			Text("When's your birthday?")
				.font(.title2.weight(.semibold))
				.foregroundStyle(.white)

			BirthdayPicker(date: $selectedDate)
		}
	}
}

private struct AccessStepView: View {
	var body: some View {
		LumioSay(text: "I'd like to know \n your local weather to \n personalise my message \n when I think of you.")
		}
}


private struct BirthdayPicker: View {
	@Binding var date: Date
	@State private var year: Int
	@State private var month: Int
	@State private var day: Int

	private let years: [Int]
	private let months: [Int] = Array(1...12)

	init(date: Binding<Date>) {
		let calendar = Calendar.current
		_date = date
		let components = calendar.dateComponents([.year, .month, .day], from: date.wrappedValue)
		_year = State(initialValue: components.year ?? 2000)
		_month = State(initialValue: components.month ?? 1)
		_day = State(initialValue: components.day ?? 1)
		let currentYear = calendar.component(.year, from: Date())
		self.years = Array(1900...currentYear)
	}

	var body: some View {
		HStack(spacing: 16) {
			selectionMenu(display: String(year)) {
				ForEach(years.reversed(), id: \.self) { value in
					Button(String(value)) {
						year = value
						syncDate()
					}
				}
			}
			.frame(width: 80, height: 40)

			selectionMenu(display: monthTitle(for: month)) {
				ForEach(months, id: \.self) { value in
					Button(monthTitle(for: value)) {
						month = value
						syncDate()
					}
				}
			}
			.frame(width: 60, height: 40)

			selectionMenu(display: String(format: "%02d", day)) {
				ForEach(daysInMonth(), id: \.self) { value in
					Button(String(format: "%02d", value)) {
						day = value
						syncDate()
					}
				}
			}
			.frame(width: 60, height: 40)
		}
	}

	private func monthTitle(for value: Int) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: Locale.current.identifier)
		formatter.setLocalizedDateFormatFromTemplate("MMM")
		var components = DateComponents()
		components.month = value
		components.day = 1
		components.year = 2000
		if let date = Calendar.current.date(from: components) {
			return formatter.string(from: date)
		}
		return "\(value)"
	}

	private func selectionMenu<Content: View>(
		display: String,
		@ViewBuilder content: () -> Content
	) -> some View {
		Menu {
			content()
		} label: {
			Text(display)
				.font(.headline)
				.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.background(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.fill(Color.white.opacity(0.15))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.stroke(Color.white.opacity(0.6), lineWidth: 1)
			)
		}
		.menuOrder(.priority)
	}

	private func daysInMonth() -> [Int] {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = 1
		let calendar = Calendar.current
		guard let date = calendar.date(from: components),
			  let range = calendar.range(of: .day, in: .month, for: date) else {
			return Array(1...31)
		}
		let upperBound = range.upperBound - 1
		if day > upperBound {
			day = upperBound
			syncDate()
		}
		return Array(range)
	}

	private func syncDate() {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		let calendar = Calendar.current
		if let updatedDate = calendar.date(from: components) {
			date = updatedDate
		}
	}
}

private struct NavigationGestureDisabler: UIViewControllerRepresentable {
	let isDisabled: Bool

	func makeUIViewController(context: Context) -> Controller {
		Controller(isDisabled: isDisabled)
	}

	func updateUIViewController(_ uiViewController: Controller, context: Context) {
		uiViewController.isDisabled = isDisabled
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
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

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
