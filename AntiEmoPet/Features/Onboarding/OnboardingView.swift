import SwiftUI
import UIKit
internal import CoreLocation

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
                Spacer(minLength: 80)

                VStack(spacing: 24) {
                    stepContent
                        .transition(.opacity)
                        .animation(.easeInOut, value: step)
                    OnboardingArrowButton(
                        isEnabled: canAdvance,
                        isLoading: isProcessingFinalStep,
                        action: handleAdvance
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.bottom, 120)
                .offset(x: dragOffset)
                .gesture(backSwipeGesture)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                Image("foxcurious")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .accessibilityHidden(true)
                    .padding(.bottom, 24)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .alert("无法获取定位", isPresented: $showLocationDeniedAlert) {
            Button("前往设置") {
                isProcessingFinalStep = false
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("继续", role: .cancel) {
                viewModel.enableLocationAndWeather = false
                finishOnboarding(shareLocation: false)
            }
        } message: {
            Text("后续任务将无法根据你当前的天气情况生成")
        }
        .onChange(of: locationService.authorizationStatus, perform: handleLocationAuthorizationChange)
        .onChange(of: locationService.lastKnownCity) { city in
            if let city {
                viewModel.region = city
            }
        }
        .onChange(of: locationService.weatherPermissionGranted) { granted in
            viewModel.setWeatherPermission(granted)
        }
        .onAppear {
            viewModel.updateLocationStatus(locationService.authorizationStatus)
            if let city = locationService.lastKnownCity {
                viewModel.region = city
            }
            viewModel.setWeatherPermission(locationService.weatherPermissionGranted)
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
            AccessStepView(region: viewModel.region, isRequesting: isProcessingFinalStep)
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
        }
    }

    func handleAdvance() {
        guard canAdvance else { return }
        switch step {
        case .access:
            handleFinalStep()
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

    func handleFinalStep() {
        guard !hasCompletedOnboarding else { return }
        viewModel.enableLocationAndWeather = true
        let status = locationService.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            isProcessingFinalStep = true
            locationService.startUpdating()
            requestWeatherAndNotifications()
        case .denied, .restricted:
            viewModel.enableLocationAndWeather = false
            isProcessingFinalStep = false
            showLocationDeniedAlert = true
        case .notDetermined:
            isProcessingFinalStep = true
            locationService.requestAuthorization()
        @unknown default:
            isProcessingFinalStep = true
            locationService.requestAuthorization()
        }
    }

    func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus) {
        viewModel.updateLocationStatus(status)
        guard step == .access else { return }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if viewModel.enableLocationAndWeather {
                isProcessingFinalStep = true
                locationService.startUpdating()
                requestWeatherAndNotifications()
            }
        case .denied, .restricted:
            if viewModel.enableLocationAndWeather {
                viewModel.enableLocationAndWeather = false
                isProcessingFinalStep = false
                showLocationDeniedAlert = true
            }
        case .notDetermined:
            break
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
            finishOnboarding(shareLocation: true)
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
                finishOnboarding(shareLocation: true)
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
        hasCompletedOnboarding = true
        isProcessingFinalStep = false
        let trimmedName = viewModel.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = viewModel.region.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.enableLocationAndWeather = shareLocation
        appModel.updateProfile(
            nickname: trimmedName,
            region: trimmedRegion,
            shareLocation: shareLocation,
            gender: viewModel.selectedGender?.rawValue ?? GenderIdentity.unspecified.rawValue,
            birthday: viewModel.birthday
        )
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

private struct IntroStepView: View {
    var body: some View {
        Text("Hey! I'm Lumio, another fox from the little prince's planet.")
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
    }
}

private struct NameStepView: View {
    @Binding var nickname: String
    let focus: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("My lovely new friend, what shall I call you?")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            TextField("Type here…", text: $nickname)
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
            Text("And you are…")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                ForEach(genderOptions) { option in
                    Button {
                        selectedGender = option
                    } label: {
                        Text(option.displayName)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(backgroundColor(for: option))
                            )
                            .overlay(
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
        option == selectedGender ? Color.white.opacity(0.25) : Color.white.opacity(0.12)
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
    var region: String
    var isRequesting: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("I'd like to know your local weather to personalise my message when I think of you.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            if !region.isEmpty {
                Text("当前定位：\(region)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if isRequesting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 8)
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
            selectionMenu(title: "Year", display: String(year)) {
                ForEach(years.reversed(), id: \.self) { value in
                    Button(String(value)) {
                        year = value
                        syncDate()
                    }
                }
            }

            selectionMenu(title: "Month", display: monthTitle(for: month)) {
                ForEach(months, id: \.self) { value in
                    Button(monthTitle(for: value)) {
                        month = value
                        syncDate()
                    }
                }
            }

            selectionMenu(title: "Day", display: String(format: "%02d", day)) {
                ForEach(daysInMonth(), id: \.self) { value in
                    Button(String(format: "%02d", value)) {
                        day = value
                        syncDate()
                    }
                }
            }
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
        title: String,
        display: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            VStack(spacing: 4) {
                Text(display)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
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
