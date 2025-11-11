import SwiftUI
internal import CoreLocation

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var appModel: AppViewModel
    @ObservedObject private var locationService: LocationService
    @State private var isRequestingWeather = false

    init(locationService: LocationService? = nil) {
        _locationService = ObservedObject(wrappedValue: locationService ?? LocationService())
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)
            Text("欢迎来到 LumioPet")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("分享你的昵称与城市，Lumio 将结合实时天气为你推荐任务。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                TextField("昵称", text: $viewModel.nickname)
                    .textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前城市")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        let cityText = viewModel.enableLocationAndWeather
                            ? (viewModel.region.isEmpty ? "定位中…" : viewModel.region)
                            : "未开启"
                        Text(cityText)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.gray.opacity(0.2)))
                }

                Toggle("允许使用定位与天气信息", isOn: $viewModel.enableLocationAndWeather)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                if isRequestingWeather {
                    ProgressView("正在请求权限…")
                }
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("接收每日提醒", isOn: $viewModel.notificationsOptIn)
            }

            PrimaryButton(title: "进入 LumioPet") {
                guard viewModel.canSubmit else { return }
                appModel.updateProfile(
                    nickname: viewModel.nickname,
                    region: viewModel.region,
                    shareLocation: viewModel.enableLocationAndWeather
                )
                if viewModel.notificationsOptIn {
                    appModel.requestNotifications()
                }
            }
            .disabled(!viewModel.canSubmit)
            Spacer()
        }
        .padding()
        .onChange(of: locationService.authorizationStatus) { status in
            viewModel.updateLocationStatus(status)
            if viewModel.enableLocationAndWeather && viewModel.hasLocationPermission {
                locationService.startUpdating()
            }
        }
        .onChange(of: locationService.lastKnownCity) { city in
            if let city {
                viewModel.region = city
            }
        }
        .onChange(of: viewModel.enableLocationAndWeather) { isEnabled in
            if isEnabled {
                locationService.requestAuthorization()
                if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                    locationService.startUpdating()
                }
                Task { @MainActor in
                    isRequestingWeather = true
                    viewModel.setWeatherPermission(false)
                    let granted = await appModel.requestWeatherAccess()
                    viewModel.setWeatherPermission(granted)
                    locationService.updateWeatherPermission(granted: granted)
                    isRequestingWeather = false
                }
            } else {
                locationService.stopUpdating()
                viewModel.setWeatherPermission(false)
            }
        }
        .onAppear {
            viewModel.updateLocationStatus(locationService.authorizationStatus)
            if let city = locationService.lastKnownCity {
                viewModel.region = city
            }
            viewModel.setWeatherPermission(locationService.weatherPermissionGranted)
        }
        .onChange(of: locationService.weatherPermissionGranted) { granted in
            viewModel.setWeatherPermission(granted)
        }
    }
}
