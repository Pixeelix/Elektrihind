//
//  NotificationService.swift
//  Elektrihind
//

import Foundation
import UserNotifications
import BackgroundTasks
import UIKit

struct RemoteNotificationSettingsSnapshot: Encodable {
    let installationId: String
    let platform: String
    let bundleId: String
    let apnsToken: String
    let apnsEnvironment: String
    let region: String
    let language: String
    let unit: String
    let includeTax: Bool
    let notifyMaxEnabled: Bool
    let notifyMaxRawMWh: Double
    let notifyMinEnabled: Bool
    let notifyMinRawMWh: Double
    let appVersion: String?
    let buildNumber: String?
}

enum NotificationDecision {
    case noop
    case fire(direction: Direction, worstHour: Date, rawPriceMWh: Double, thresholdRawMWh: Double)
    case dataNotReady

    enum Direction { case max, min }
}

class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private let installationIdKey = "remoteNotificationInstallationId"
    private let apnsTokenKey = "remoteNotificationAPNSToken"

    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await center.notificationSettings().authorizationStatus
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        return await center.notificationSettings().authorizationStatus
    }

    @MainActor
    func registerForRemoteNotificationsIfNeeded() async {
        let authStatus = await currentAuthorizationStatus()
        guard authStatus == .authorized || authStatus == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func updateRemoteDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: apnsTokenKey)
        Task {
            await syncRemoteSettingsFromDefaults()
        }
    }

    func remoteRegistrationDidFail(_ error: Error) {
        debugPrint("APNs registration failed: \(error.localizedDescription)")
    }

    func syncRemoteSettings(settings: AppSettings) {
        guard let snapshot = makeRemoteSettingsSnapshot(settings: settings) else { return }
        Task {
            await sendRemoteSettings(snapshot)
        }
    }

    func syncRemoteSettingsFromDefaults() async {
        guard let snapshot = makeRemoteSettingsSnapshotFromDefaults() else { return }
        await sendRemoteSettings(snapshot)
    }

    func evaluateTomorrow(
        notifyMaxEnabled: Bool,
        notifyMaxRawMWh: Double,
        notifyMinEnabled: Bool,
        notifyMinRawMWh: Double,
        region: Region
    ) async -> NotificationDecision {
        guard notifyMaxEnabled || notifyMinEnabled else { return .noop }

        do {
            let prices = try await NetworkService().loadFullDayData(.tomorrow, region: region)
            let expectedCount = PriceCache.expectedHourCount(for: .tomorrow)
            guard prices.count == expectedCount else { return .dataNotReady }

            if notifyMaxEnabled,
               let worst = prices.max(by: { $0.price < $1.price }),
               worst.price >= notifyMaxRawMWh,
               !alreadyFired(direction: .max) {
                return .fire(
                    direction: .max,
                    worstHour: Date(timeIntervalSince1970: worst.timestamp),
                    rawPriceMWh: worst.price,
                    thresholdRawMWh: notifyMaxRawMWh
                )
            }

            if notifyMinEnabled,
               let worst = prices.min(by: { $0.price < $1.price }),
               worst.price <= notifyMinRawMWh,
               !alreadyFired(direction: .min) {
                return .fire(
                    direction: .min,
                    worstHour: Date(timeIntervalSince1970: worst.timestamp),
                    rawPriceMWh: worst.price,
                    thresholdRawMWh: notifyMinRawMWh
                )
            }

            return .noop
        } catch {
            return .noop
        }
    }

    func scheduleNotification(
        _ decision: NotificationDecision,
        region: Region,
        includeTax: Bool,
        divider: Double,
        taxRate: Double,
        unit: String,
        language: Language,
        numberFormatter: NumberFormatter
    ) async {
        guard case .fire(let direction, let worstHour, let rawPrice, let thresholdRaw) = decision else { return }

        let authStatus = await currentAuthorizationStatus()
        guard authStatus == .authorized || authStatus == .provisional else { return }

        let displayed = (rawPrice * (includeTax ? taxRate : 1)) / divider
        let thresholdDisplayed = (thresholdRaw * (includeTax ? taxRate : 1)) / divider
        let priceStr = numberFormatter.string(from: NSNumber(value: displayed)) ?? String(format: "%.2f", displayed)
        let thresholdStr = numberFormatter.string(from: NSNumber(value: thresholdDisplayed)) ?? String(format: "%.2f", thresholdDisplayed)

        let timeFmt = DateFormatter()
        timeFmt.timeZone = TimeZoneHelper.timeZone(for: region)
        timeFmt.dateFormat = "HH:mm"
        let timeStr = timeFmt.string(from: worstHour)

        let titleKey = direction == .max ? "NOTIF_TITLE_MAX" : "NOTIF_TITLE_MIN"
        let bodyKey = direction == .max ? "NOTIF_BODY_MAX" : "NOTIF_BODY_MIN"

        let title = titleKey.localized(language, in: .main)
        let bodyTemplate = bodyKey.localized(language, in: .main)
        let body = String(format: bodyTemplate, "\(priceStr) \(unit)", timeStr, "\(thresholdStr) \(unit)")

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let identifier = "elektrihind.threshold.\(direction == .max ? "max" : "min")"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try? await center.add(request)
        markFired(direction: direction)
    }

    @MainActor
    func runForegroundCheck(settings: AppSettings) async {
        guard settings.notifyMaxEnabled || settings.notifyMinEnabled else { return }

        let maxEnabled = settings.notifyMaxEnabled
        let maxRaw = settings.notifyMaxRawMWh
        let minEnabled = settings.notifyMinEnabled
        let minRaw = settings.notifyMinRawMWh
        let region = settings.region
        let includeTax = settings.includeTax
        let divider = settings.divider
        let taxRate = settings.taxRate
        let unit = settings.unit
        let language = settings.language
        let fmt = settings.numberFormatter

        let decision = await evaluateTomorrow(
            notifyMaxEnabled: maxEnabled, notifyMaxRawMWh: maxRaw,
            notifyMinEnabled: minEnabled, notifyMinRawMWh: minRaw,
            region: region
        )

        if case .fire = decision {
            await scheduleNotification(
                decision, region: region, includeTax: includeTax,
                divider: divider, taxRate: taxRate, unit: unit,
                language: language, numberFormatter: fmt
            )
        }
    }

    func scheduleTestNotification(settings: AppSettings) async {
        let authStatus = await requestAuthorization()
        guard authStatus == .authorized || authStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "TEST: " + "NOTIF_TITLE_MAX".localized(settings.language, in: .main)
        content.body = "TEST: " + String(format: "NOTIF_BODY_MAX".localized(settings.language, in: .main),
                                         "150 \(settings.unit)", "18:00", "100 \(settings.unit)")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "elektrihind.test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        try? await center.add(request)
    }

    // MARK: - Dedup tracking

    private func tomorrowDateString() -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Tallinn")!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        return "\(comps.year!)-\(String(format: "%02d", comps.month!))-\(String(format: "%02d", comps.day!))"
    }

    private func firedKey(for direction: NotificationDecision.Direction) -> String {
        direction == .max ? "notifyMaxFiredDate" : "notifyMinFiredDate"
    }

    private func alreadyFired(direction: NotificationDecision.Direction) -> Bool {
        UserDefaults.standard.string(forKey: firedKey(for: direction)) == tomorrowDateString()
    }

    private func markFired(direction: NotificationDecision.Direction) {
        UserDefaults.standard.set(tomorrowDateString(), forKey: firedKey(for: direction))
    }

    // MARK: - Remote push backend

    private var pushBackendBaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PushBackendBaseURL") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), let url = URL(string: trimmed) else {
            return nil
        }
        return url
    }

    private var storedAPNSToken: String? {
        let token = UserDefaults.standard.string(forKey: apnsTokenKey) ?? ""
        return token.isEmpty ? nil : token
    }

    private func installationId() -> String {
        if let existing = UserDefaults.standard.string(forKey: installationIdKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: installationIdKey)
        return created
    }

    private func apnsEnvironment() -> String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private func appVersion() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private func buildNumber() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    private func bundleId() -> String {
        Bundle.main.bundleIdentifier ?? "koodipardik.Elektrihind"
    }

    private func makeRemoteSettingsSnapshot(settings: AppSettings) -> RemoteNotificationSettingsSnapshot? {
        guard let token = storedAPNSToken else { return nil }
        return RemoteNotificationSettingsSnapshot(
            installationId: installationId(),
            platform: "ios",
            bundleId: bundleId(),
            apnsToken: token,
            apnsEnvironment: apnsEnvironment(),
            region: settings.region.rawValue,
            language: settings.language.rawValue,
            unit: settings.unit,
            includeTax: settings.includeTax,
            notifyMaxEnabled: settings.notifyMaxEnabled,
            notifyMaxRawMWh: settings.notifyMaxRawMWh,
            notifyMinEnabled: settings.notifyMinEnabled,
            notifyMinRawMWh: settings.notifyMinRawMWh,
            appVersion: appVersion(),
            buildNumber: buildNumber()
        )
    }

    private func makeRemoteSettingsSnapshotFromDefaults() -> RemoteNotificationSettingsSnapshot? {
        guard let token = storedAPNSToken else { return nil }
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["notifyMaxRawMWh": 200.0, "notifyMinRawMWh": 0.0])

        return RemoteNotificationSettingsSnapshot(
            installationId: installationId(),
            platform: "ios",
            bundleId: bundleId(),
            apnsToken: token,
            apnsEnvironment: apnsEnvironment(),
            region: defaults.string(forKey: "region") ?? "EE",
            language: defaults.string(forKey: "language") ?? "et",
            unit: defaults.string(forKey: "unit") ?? "€/kWh",
            includeTax: defaults.bool(forKey: "includeTax"),
            notifyMaxEnabled: defaults.bool(forKey: "notifyMaxEnabled"),
            notifyMaxRawMWh: defaults.double(forKey: "notifyMaxRawMWh"),
            notifyMinEnabled: defaults.bool(forKey: "notifyMinEnabled"),
            notifyMinRawMWh: defaults.double(forKey: "notifyMinRawMWh"),
            appVersion: appVersion(),
            buildNumber: buildNumber()
        )
    }

    private func sendRemoteSettings(_ snapshot: RemoteNotificationSettingsSnapshot) async {
        guard let baseURL = pushBackendBaseURL else { return }
        let url = baseURL.appendingPathComponent("v1/devices")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(snapshot)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                debugPrint("Push backend sync failed with status \(http.statusCode)")
            }
        } catch {
            debugPrint("Push backend sync failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - BGScheduler

enum BGScheduler {
    static let taskIdentifier = "koodipardik.Elektrihind.priceCheck"

    static func scheduleIfNeeded() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextEarliestBeginDate()
        try? BGTaskScheduler.shared.submit(request)
    }

    static func scheduleRetry() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    static func nextEarliestBeginDate() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Tallinn")!
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = 14
        comps.minute = 15
        var candidate = cal.date(from: comps)!
        if candidate <= now {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate)!
        }
        return candidate
    }

    static func handle(_ task: BGAppRefreshTask) {
        UserDefaults.standard.register(defaults: ["notifyMaxRawMWh": 200.0, "notifyMinRawMWh": 0.0])

        let defaults = UserDefaults.standard
        let notifyMaxEnabled = defaults.bool(forKey: "notifyMaxEnabled")
        let notifyMaxRawMWh = defaults.double(forKey: "notifyMaxRawMWh")
        let notifyMinEnabled = defaults.bool(forKey: "notifyMinEnabled")
        let notifyMinRawMWh = defaults.double(forKey: "notifyMinRawMWh")

        guard notifyMaxEnabled || notifyMinEnabled else {
            task.setTaskCompleted(success: true)
            return
        }

        let regionStr = defaults.string(forKey: "region") ?? "EE"
        let region = Region(rawValue: regionStr) ?? .estonia
        let includeTax = defaults.bool(forKey: "includeTax")
        let unit = defaults.string(forKey: "unit") ?? "€/kWh"
        let langStr = defaults.string(forKey: "language") ?? "et"
        let language = Language(rawValue: langStr) ?? .estonian
        let priceConfig = PriceFormatter.formatter(for: unit)
        let retryKey = retryCountKey()
        let retries = defaults.integer(forKey: retryKey)

        task.expirationHandler = {
            scheduleIfNeeded()
            task.setTaskCompleted(success: false)
        }

        Task {
            let decision = await NotificationService.shared.evaluateTomorrow(
                notifyMaxEnabled: notifyMaxEnabled,
                notifyMaxRawMWh: notifyMaxRawMWh,
                notifyMinEnabled: notifyMinEnabled,
                notifyMinRawMWh: notifyMinRawMWh,
                region: region
            )

            switch decision {
            case .fire:
                await NotificationService.shared.scheduleNotification(
                    decision,
                    region: region,
                    includeTax: includeTax,
                    divider: priceConfig.divider,
                    taxRate: TaxConfiguration.taxRate(for: region),
                    unit: unit,
                    language: language,
                    numberFormatter: priceConfig.formatter
                )
                defaults.removeObject(forKey: retryKey)
                scheduleIfNeeded()

            case .dataNotReady:
                if retries < 4 {
                    defaults.set(retries + 1, forKey: retryKey)
                    scheduleRetry()
                } else {
                    defaults.removeObject(forKey: retryKey)
                    scheduleIfNeeded()
                }

            case .noop:
                defaults.removeObject(forKey: retryKey)
                scheduleIfNeeded()
            }

            task.setTaskCompleted(success: true)
        }
    }

    private static func retryCountKey() -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Tallinn")!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        return "notifyRetryCount:\(comps.year!)-\(String(format: "%02d", comps.month!))-\(String(format: "%02d", comps.day!))"
    }
}
