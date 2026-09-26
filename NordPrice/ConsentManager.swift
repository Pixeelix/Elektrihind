//
//  ConsentManager.swift
//  NordPrice
//
//  Created by Martin Pihooja on 24.07.2023.
//

import Foundation
import GoogleMobileAds
import UserMessagingPlatform

/// Gathers GDPR (UMP) consent and starts the Mobile Ads SDK once ads may be
/// requested. The ATT prompt is shown by UMP's IDFA explainer message (set up in
/// the AdMob console), after the GDPR form — never before it.
@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false

    private var isGathering = false
    private var hasStartedAds = false

    private init() {}

    func gatherConsent() {
        guard !AppRuntimeConfiguration.skipsAdConsent, !isGathering else { return }
        isGathering = true

        // Consent from a previous session is valid right away; don't wait for the network.
        refreshState()

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("❌ Consent info update failed: \(error.localizedDescription)")
                    self.finishGathering()
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: nil) { [weak self] formError in
                    Task { @MainActor in
                        if let formError {
                            print("❌ Consent form failed: \(formError.localizedDescription)")
                        }
                        self?.finishGathering()
                    }
                }
            }
        }
    }

    func presentPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: nil) { [weak self] error in
            Task { @MainActor in
                if let error {
                    print("❌ Privacy options form failed: \(error.localizedDescription)")
                }
                self?.refreshState()
            }
        }
    }

    private func finishGathering() {
        isGathering = false
        refreshState()
    }

    private func refreshState() {
        let info = ConsentInformation.shared
        privacyOptionsRequired = info.privacyOptionsRequirementStatus == .required
        canRequestAds = info.canRequestAds

        if canRequestAds && !hasStartedAds {
            hasStartedAds = true
            MobileAds.shared.start()
        }
    }
}
