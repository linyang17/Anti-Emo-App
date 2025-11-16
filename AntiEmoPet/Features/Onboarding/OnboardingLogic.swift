import SwiftUI


struct FoxCharacterLayer: View {
    var body: some View {
        VStack {
            Spacer()
            Image("foxcurious")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(.bottom, 80)
        }
        .transition(.opacity)
    }
}

struct StepFactory: View {
	let step: OnboardingView.Step
	@ObservedObject var viewModel: OnboardingViewModel
	let onAdvance: () -> Void

	@ViewBuilder
	var body: some View {
		switch step {
		case .intro:
			IntroStepView()

		case .registration:
			RegistrationStepView(viewModel: viewModel)

		case .name:
			NameStepView(
				nickname: $viewModel.nickname,
				onSubmit: onAdvance
			)

		case .gender:
			GenderStepView(selectedGender: $viewModel.selectedGender)

		case .birthday:
			BirthdayStepView(selectedDate: $viewModel.birthday)

		case .access:
			AccessStepView()

		case .celebration:
			WelcomeView {
				onAdvance()
			}
		}
	}
}

struct IntroStepView: View, Equatable {
	static func == (lhs: Self, rhs: Self) -> Bool { true }
	var body: some View {
		LumioSay(text: "Hey! I'm Lumio,\n another fox from\n the little prince's planet.")
	}
}


struct RegistrationStepView: View, Equatable {
	@ObservedObject var viewModel: OnboardingViewModel
	static func == (lhs: RegistrationStepView, rhs: RegistrationStepView) -> Bool {
		lhs.viewModel.selectedAccountProvider == rhs.viewModel.selectedAccountProvider &&
		lhs.viewModel.accountEmail == rhs.viewModel.accountEmail
	}

	var body: some View {
		VStack(spacing: 20) {
			LumioSay(text: "How'd you like to register?")
			HStack(spacing: 12) {
				providerButton(title: "Google", systemImage: "g.circle", provider: .google)
				providerButton(title: "iCloud", systemImage: "icloud", provider: .icloud)
			}
			.frame(maxWidth: 240)
			registrationStatus
		}
	}

	@ViewBuilder
	private var registrationStatus: some View {
		if let provider = viewModel.selectedAccountProvider {
			VStack(spacing: 8) {
				Label("Connected via \(provider.title)\n\(viewModel.accountEmail)",
					  systemImage: "checkmark.seal.fill")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.white.opacity(0.85))
			}
		}
	}

	private func providerButton(title: String, systemImage: String,
								provider: OnboardingViewModel.AccountProvider) -> some View {
		let isSelected = viewModel.selectedAccountProvider == provider
		return Button { viewModel.selectAccountProvider(provider) } label: {
			HStack {
				Image(systemName: systemImage)
				Text(title)
					.font(.subheadline.weight(isSelected ? .bold : .semibold))
			}
			.foregroundStyle(.white)
			.padding()
			.frame(maxWidth: .infinity)
			.background(
				RoundedRectangle(cornerRadius: 18)
					.fill(Color.white.opacity(isSelected ? 0.25 : 0.12))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 18)
					.stroke(Color.white.opacity(isSelected ? 1 : 0.4),
							lineWidth: isSelected ? 1.5 : 0.8)
			)
		}
		.buttonStyle(.plain)
	}
}



struct NameStepView: View, Equatable {
	@Binding var nickname: String
	let onSubmit: () -> Void

	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.nickname == rhs.nickname
	}

	var body: some View {
		VStack(spacing: 24) {
			LumioSay(text: "My lovely new friend,\n what shall I call you?")
			TextField("Type here…", text: $nickname)
				.frame(width: 200, height: 40)
				.padding(.vertical, 14)
				.padding(.horizontal, 18)
				.background(
					RoundedRectangle(cornerRadius: 18)
						.stroke(Color.white.opacity(0.6))
						.background(
							RoundedRectangle(cornerRadius: 18)
								.fill(Color.white.opacity(0.15))
						)
				)
				.foregroundStyle(.white)
				.tint(.white)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.words)
				.submitLabel(.done)
				.onSubmit(onSubmit)
		}
	}
}


struct GenderStepView: View, Equatable {
	@Binding var selectedGender: OnboardingViewModel.GenderOption?
	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.selectedGender == rhs.selectedGender
	}

	var body: some View {
		VStack(spacing: 24) {
			LumioSay(text: "And you are…")
			HStack(spacing: 16) {
				ForEach(OnboardingViewModel.GenderOption.allCases) { option in
					Button { selectedGender = option } label: {
						Text(option.displayName)
							.font(.system(size: 15, weight: .medium, design: .rounded))
							.frame(width: 70, height: 40)
							.background(
								RoundedRectangle(cornerRadius: 18)
									.fill(backgroundColor(for: option))
							)
							.overlay(
								RoundedRectangle(cornerRadius: 18)
									.stroke(Color.white.opacity(0.9),
											lineWidth: option == selectedGender ? 1.5 : 0.8)
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


struct BirthdayStepView: View, Equatable {
	@Binding var selectedDate: Date
	static func == (lhs: Self, rhs: Self) -> Bool { lhs.selectedDate == rhs.selectedDate }

	var body: some View {
		VStack(spacing: 24) {
			Text("When's your birthday?")
				.font(.title2.weight(.semibold))
				.foregroundStyle(.white)
			BirthdayPicker(date: $selectedDate)
		}
	}
}

struct BirthdayPicker: View {
	@Binding var date: Date
	@State private var year: Int
	@State private var month: Int
	@State private var day: Int

	private let years: [Int]
	private let months: [Int] = Array(1...12)

	init(date: Binding<Date>) {
		let calendar = Calendar.current
		_date = date
		let comp = calendar.dateComponents([.year, .month, .day], from: date.wrappedValue)
		_year = State(initialValue: comp.year ?? 2000)
		_month = State(initialValue: comp.month ?? 1)
		_day = State(initialValue: comp.day ?? 1)
		let currentYear = calendar.component(.year, from: Date())
		years = Array(1900...currentYear)
	}

	var body: some View {
		HStack(spacing: 16) {
			pickerMenu(display: String(year)) {
				ForEach(years.reversed(), id: \.self) { v in Button(String(v)) { year = v; syncDate() } }
			}
			.frame(width: 80)
			pickerMenu(display: monthTitle(month)) {
				ForEach(months, id: \.self) { v in Button(monthTitle(v)) { month = v; syncDate() } }
			}
			.frame(width: 60)
			pickerMenu(display: String(format: "%02d", day)) {
				ForEach(daysInMonth(), id: \.self) { v in Button(String(format: "%02d", v)) { day = v; syncDate() } }
			}
			.frame(width: 60)
		}
	}

	private func monthTitle(_ value: Int) -> String {
		let formatter = DateFormatter()
		formatter.locale = .current
		formatter.setLocalizedDateFormatFromTemplate("MMM")
		var c = DateComponents(); c.year = 2000; c.month = value; c.day = 1
		if let d = Calendar.current.date(from: c) { return formatter.string(from: d) }
		return "\(value)"
	}

	private func pickerMenu<Content: View>(display: String, @ViewBuilder content: () -> Content) -> some View {
		Menu { content() } label: {
			Text(display)
				.font(.headline)
				.foregroundStyle(.white)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.15)))
				.overlay(RoundedRectangle(cornerRadius: 18)
							.stroke(Color.white.opacity(0.6), lineWidth: 1))
		}
		.menuOrder(.priority)
	}

	private func daysInMonth() -> [Int] {
		var comp = DateComponents(); comp.year = year; comp.month = month; comp.day = 1
		let cal = Calendar.current
		guard let date = cal.date(from: comp),
			  let range = cal.range(of: .day, in: .month, for: date) else { return Array(1...31) }
		let maxDay = range.upperBound - 1
		if day > maxDay { day = maxDay; syncDate() }
		return Array(range)
	}

	private func syncDate() {
		var comp = DateComponents(); comp.year = year; comp.month = month; comp.day = day
		if let new = Calendar.current.date(from: comp) { date = new }
	}
}


struct AccessStepView: View, Equatable {
	static func == (lhs: Self, rhs: Self) -> Bool { true }
	var body: some View {
		LumioSay(text: "I'd like to know\n your local weather to\n personalise my message\n when I think of you.")
	}
}

