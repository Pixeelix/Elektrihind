//
//  NotificationService.swift
//  NordPrice
//

import Foundation
import FirebaseAuth
import FirebaseFunctions
import FirebaseMessaging
import UserNotifications
import UIKit

struct RemoteNotificationSettingsSnapshot {
    let installationId: String
    let platform: String
    let bundleId: String
    let fcmToken: String
    let region: String
    let language: String
    let unit: String
    let includeTax: Bool
    let chartResolution: String
    let notifyMaxEnabled: Bool
    let notifyMaxRawMWh: Double
    let notifyMinEnabled: Bool
    let notifyMinRawMWh: Double
    let appVersion: String?
    let buildNumber: String?

    var enabled: Bool {
        notifyMaxEnabled || notifyMinEnabled
    }

    var payload: [String: Any] {
        var data: [String: Any] = [
            "installationId": installationId,
            "platform": platform,
            "bundleId": bundleId,
            "fcmToken": fcmToken,
            "region": region,
            "language": language,
            "unit": unit,
            "includeTax": includeTax,
            "chartResolution": chartResolution,
            "notifyMaxEnabled": notifyMaxEnabled,
            "notifyMaxRawMWh": notifyMaxRawMWh,
            "notifyMinEnabled": notifyMinEnabled,
            "notifyMinRawMWh": notifyMinRawMWh,
            "enabled": enabled
        ]

        if let appVersion {
            data["appVersion"] = appVersion
        }

        if let buildNumber {
            data["buildNumber"] = buildNumber
        }

        return data
    }
}

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let installationIdKey = "remoteNotificationInstallationId"
    private let fcmTokenKey = "remoteNotificationFCMToken"
    private let firebaseFunctionsRegion = "europe-west1"
    private lazy var functions = Functions.functions(region: firebaseFunctionsRegion)

    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
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
        Messaging.messaging().apnsToken = deviceToken
        refreshFCMTokenAndSync()
    }

    func updateFCMToken(_ fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        UserDefaults.standard.set(fcmToken, forKey: fcmTokenKey)
        #if DEBUG
        debugPrint("FCM token: \(fcmToken)")
        #endif

        Task {
            await syncRemoteSettingsFromDefaults()
        }
    }

    func remoteRegistrationDidFail(_ error: Error) {
        debugPrint("Remote notification registration failed: \(error.localizedDescription)")
    }

    func syncRemoteSettings(settings: AppSettings) {
        let input = NotificationSettingsInput(
            region: settings.region.rawValue,
            language: settings.language.rawValue,
            unit: settings.unit,
            includeTax: settings.includeTax,
            chartResolution: settings.chartResolution.rawValue,
            notifyMaxEnabled: settings.notifyMaxEnabled,
            notifyMaxRawMWh: settings.notifyMaxRawMWh,
            notifyMinEnabled: settings.notifyMinEnabled,
            notifyMinRawMWh: settings.notifyMinRawMWh
        )

        Task {
            guard let snapshot = await makeRemoteSettingsSnapshot(input: input) else { return }
            await sendRemoteSettings(snapshot)
        }
    }

    func syncRemoteSettingsFromDefaults() async {
        UserDefaults.standard.register(defaults: ["notifyMaxRawMWh": 200.0, "notifyMinRawMWh": 0.0])
        let defaults = UserDefaults.standard
        let input = NotificationSettingsInput(
            region: defaults.string(forKey: "region") ?? "EE",
            language: defaults.string(forKey: "language") ?? "et",
            unit: defaults.string(forKey: "unit") ?? "€/kWh",
            includeTax: defaults.bool(forKey: "includeTax"),
            chartResolution: defaults.string(forKey: "chartResolution") ?? ChartResolution.oneHour.rawValue,
            notifyMaxEnabled: defaults.bool(forKey: "notifyMaxEnabled"),
            notifyMaxRawMWh: defaults.double(forKey: "notifyMaxRawMWh"),
            notifyMinEnabled: defaults.bool(forKey: "notifyMinEnabled"),
            notifyMinRawMWh: defaults.double(forKey: "notifyMinRawMWh")
        )

        guard let snapshot = await makeRemoteSettingsSnapshot(input: input) else { return }
        await sendRemoteSettings(snapshot)
    }

    private func refreshFCMTokenAndSync() {
        guard Messaging.messaging().apnsToken != nil else {
            #if DEBUG
            debugPrint("Waiting for APNs token before fetching FCM token")
            #endif
            return
        }

        Messaging.messaging().token { [weak self] token, error in
            if let error {
                debugPrint("FCM token refresh failed: \(error.localizedDescription)")
                return
            }

            self?.updateFCMToken(token)
        }
    }

    private func storedFCMToken() -> String? {
        let token = UserDefaults.standard.string(forKey: fcmTokenKey) ?? ""
        return token.isEmpty ? nil : token
    }

    private func resolvedFCMToken() async -> String? {
        if let token = storedFCMToken() {
            return token
        }

        guard Messaging.messaging().apnsToken != nil else {
            #if DEBUG
            debugPrint("Waiting for APNs token before fetching FCM token")
            #endif
            return nil
        }

        let fcmTokenKey = fcmTokenKey
        return await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error {
                    debugPrint("FCM token fetch failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                if let token, !token.isEmpty {
                    UserDefaults.standard.set(token, forKey: fcmTokenKey)
                    #if DEBUG
                    debugPrint("FCM token: \(token)")
                    #endif
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func installationId() -> String {
        if let existing = UserDefaults.standard.string(forKey: installationIdKey), !existing.isEmpty {
            return existing
        }

        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: installationIdKey)
        return created
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

    private func makeRemoteSettingsSnapshot(input: NotificationSettingsInput) async -> RemoteNotificationSettingsSnapshot? {
        guard let token = await resolvedFCMToken() else { return nil }

        return RemoteNotificationSettingsSnapshot(
            installationId: installationId(),
            platform: "ios",
            bundleId: bundleId(),
            fcmToken: token,
            region: input.region,
            language: input.language,
            unit: input.unit,
            includeTax: input.includeTax,
            chartResolution: input.chartResolution,
            notifyMaxEnabled: input.notifyMaxEnabled,
            notifyMaxRawMWh: input.notifyMaxRawMWh,
            notifyMinEnabled: input.notifyMinEnabled,
            notifyMinRawMWh: input.notifyMinRawMWh,
            appVersion: appVersion(),
            buildNumber: buildNumber()
        )
    }

    private func sendRemoteSettings(_ snapshot: RemoteNotificationSettingsSnapshot) async {
        do {
            try await ensureAnonymousAuth()
            try await callSyncNotificationDevice(payload: snapshot.payload)
        } catch {
            debugPrint("Firebase notification sync failed: \(error.localizedDescription)")
        }
    }

    private func ensureAnonymousAuth() async throws {
        if Auth.auth().currentUser != nil {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().signInAnonymously { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func callSyncNotificationDevice(payload: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            functions.httpsCallable("syncNotificationDevice").call(payload) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

private struct NotificationSettingsInput {
    let region: String
    let language: String
    let unit: String
    let includeTax: Bool
    let chartResolution: String
    let notifyMaxEnabled: Bool
    let notifyMaxRawMWh: Double
    let notifyMinEnabled: Bool
    let notifyMinRawMWh: Double
}
