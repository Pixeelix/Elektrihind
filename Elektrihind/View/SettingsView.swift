//
//  SettingsView.swift
//  NordPrice
//
//  Created by Martin Pihooja on 14.12.2021.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    let unitsArray = ["€/kWh", "€/MWh", "cent/kWh"]
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    @State private var notifDenied: Bool = false
    @State private var thresholdFocused: Bool = false
    @State private var maxProxy = ThresholdFieldProxy()
    @State private var minProxy = ThresholdFieldProxy()

    init() {
        let app = UINavigationBarAppearance()
        app.configureWithTransparentBackground()
        app.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        app.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = app
        UINavigationBar.appearance().scrollEdgeAppearance = app
        UINavigationBar.appearance().compactAppearance = app
    }

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                displaySection
                notificationsSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { Color.backgroundColor.ignoresSafeArea() }
            .navigationTitle(settings.localizedString("LABEL_SETTINGS"))
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                if !thresholdFocused { adBanner }
            }
        }
        .tint(.blue)
    }

    @ViewBuilder
    private var adBanner: some View {
        AdaptiveBannerAd(unitID: AdUnit.settingsBanner)
            .frame(maxWidth: .infinity, maxHeight: 50)
            .background(.bar)
    }

    private var generalSection: some View {
        Section {
            Picker(selection: $settings.language) {
                ForEach(Language.allLanguages, id: \.self) { lang in
                    Text(settings.localizedString(lang.name)).tag(lang)
                }
            } label: {
                rowLabel(settings.localizedString("TITLE_LANGUAGE"), symbol: "globe", tint: .blue)
            }
            .pickerStyle(.navigationLink)

            Picker(selection: $settings.region) {
                ForEach(Region.allRegions, id: \.self) { region in
                    Text(settings.localizedString(region.name)).tag(region)
                }
            } label: {
                rowLabel(settings.localizedString("TITLE_REGION"), symbol: "flag.fill", tint: .red)
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text(settings.localizedString("TITLE_GENERAL"))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var displaySection: some View {
        Section {
            Picker(selection: $settings.unit) {
                ForEach(unitsArray, id: \.self) { unit in
                    Text(settings.localizedString(unit)).tag(unit)
                }
            } label: {
                rowLabel(settings.localizedString("TITLE_UNIT"), symbol: "eurosign.circle.fill", tint: .orange)
            }
            .pickerStyle(.navigationLink)

            Toggle(isOn: $settings.includeTax) {
                rowLabel(settings.localizedString("TITLE_INCLUDE_TAX"), symbol: "percent", tint: .green)
            }

            LabeledContent {
                Text(settings.taxPercentage)
            } label: {
                rowLabel(settings.localizedString("TITLE_VAT"), symbol: "doc.text", tint: .gray)
            }

            Picker(selection: $settings.chartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(settings.localizedString(chartTypeKey(type))).tag(type)
                }
            } label: {
                rowLabel(settings.localizedString("TITLE_CHART_TYPE"), symbol: "chart.line.uptrend.xyaxis", tint: .purple)
            }
            .pickerStyle(.navigationLink)

            Picker(selection: $settings.chartResolution) {
                ForEach(ChartResolution.allCases, id: \.self) { res in
                    Text(res.label).tag(res)
                }
            } label: {
                rowLabel(settings.localizedString("TITLE_CHART_RESOLUTION"), symbol: "chart.bar.fill", tint: .blue)
            }
            .pickerStyle(.navigationLink)

            Toggle(isOn: $settings.alwaysOnDisplay) {
                rowLabel(settings.localizedString("TITLE_ALWAYS_ON_DISPLAY"), symbol: "sun.max.fill", tint: .yellow)
            }
        } header: {
            Text(settings.localizedString("TITLE_DISPLAY"))
                .foregroundStyle(.white.opacity(0.85))
        } footer: {
            Text(settings.localizedString("FOOTER_VAT"))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $settings.notifyMaxEnabled) {
                rowLabel(settings.localizedString("LABEL_NOTIFY_MAX"), symbol: "bell.badge.fill", tint: .red)
            }
            .onChange(of: settings.notifyMaxEnabled) { newValue in
                if newValue {
                    Task {
                        let status = await NotificationService.shared.requestAuthorization()
                        notifDenied = status == .denied
                        guard status != .denied else {
                            settings.notifyMaxEnabled = false
                            return
                        }
                        await NotificationService.shared.registerForRemoteNotificationsIfNeeded()
                        settings.syncRemoteNotificationPreferences()
                    }
                }
            }
            
            if settings.notifyMaxEnabled {
                HStack {
                    Text(settings.localizedString("LABEL_THRESHOLD") + " (\(settings.unit))")
                    Spacer()
                    ThresholdTextField(
                        value: Binding(
                            get: { settings.notifyMaxDisplay },
                            set: { settings.notifyMaxDisplay = $0 }
                        ),
                        formatter: settings.numberFormatter,
                        proxy: maxProxy,
                        onFocus: { thresholdFocused = true },
                        onBlur: { thresholdFocused = false }
                    )
                    .frame(width: 110)
                }
                .contentShape(Rectangle())
                .onTapGesture { maxProxy.focus() }
            }

            Toggle(isOn: $settings.notifyMinEnabled) {
                rowLabel(settings.localizedString("LABEL_NOTIFY_MIN"), symbol: "bell.badge.fill", tint: .red)
            }
            .onChange(of: settings.notifyMinEnabled) { newValue in
                if newValue {
                    Task {
                        let status = await NotificationService.shared.requestAuthorization()
                        notifDenied = status == .denied
                        guard status != .denied else {
                            settings.notifyMinEnabled = false
                            return
                        }
                        await NotificationService.shared.registerForRemoteNotificationsIfNeeded()
                        settings.syncRemoteNotificationPreferences()
                    }
                }
            }

            if settings.notifyMinEnabled {
                HStack {
                    Text(settings.localizedString("LABEL_THRESHOLD") + " (\(settings.unit))")
                    Spacer()
                    ThresholdTextField(
                        value: Binding(
                            get: { settings.notifyMinDisplay },
                            set: { settings.notifyMinDisplay = $0 }
                        ),
                        formatter: settings.numberFormatter,
                        proxy: minProxy,
                        onFocus: { thresholdFocused = true },
                        onBlur: { thresholdFocused = false }
                    )
                    .frame(width: 110)
                }
                .contentShape(Rectangle())
                .onTapGesture { minProxy.focus() }
            }

//            Button {
//                Task {
//                    await NotificationService.shared.scheduleTestNotification(settings: settings)
//                }
//            } label: {
//                rowLabel("Saada testteavitus (5s viivitus)", symbol: "paperplane.fill", tint: .blue)
//            }

            if notifDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    rowLabel(settings.localizedString("HINT_NOTIFICATIONS_DENIED"), symbol: "gear", tint: .gray)
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(settings.localizedString("TITLE_NOTIFICATIONS"))
                .foregroundStyle(.white.opacity(0.85))
        }
//        footer: {
//            Text(settings.localizedString("FOOTER_NOTIFICATIONS"))
//                .foregroundStyle(.white.opacity(0.7))
//        }
        .onAppear {
            Task {
                let status = await NotificationService.shared.currentAuthorizationStatus()
                notifDenied = status == .denied
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(appVersion ?? "")
            } label: {
                rowLabel(settings.localizedString("TITLE_VERSION"), symbol: "info.circle.fill", tint: .gray)
            }

            Text(settings.localizedString("TEXT_INFORMATION_ABOUT_APP"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(settings.localizedString("TEXT_IFORMATION_ABOUT_MARKET_TIME_UNIT"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(settings.localizedString("TITLE_ABOUT"))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private func rowLabel(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: symbol, tint: tint)
            Text(title)
        }
    }

    private func chartTypeKey(_ type: ChartType) -> String {
        switch type {
        case .bar: return "CHART_TYPE_BAR"
        case .line: return "CHART_TYPE_LINE"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppSettings())
    }
}
