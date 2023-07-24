//
//  UMPViewController.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 24.07.2023.
//

import UIKit
import UserMessagingPlatform
import SwiftUI

class UMPViewController: UIViewController {
    var canLoadAdsCallback: (() -> Void)?
    
    init() {
        super.init(nibName: nil, bundle: nil)
        // Perform any initialization logic here
        let parameters = UMPRequestParameters()
        // Set tag for under age of consent. Here false means users are not under age.
        parameters.tagForUnderAgeOfConsent = false
        
        // Request an update to the consent information.
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(
            with: parameters,
            completionHandler: { error in
                if error != nil {
                    // Handle the error.
                } else {
                    // The consent information state was updated.
                    // You are now ready to check if a form is
                    // available.
                    let formStatus = UMPConsentInformation.sharedInstance.formStatus
                    if formStatus == UMPFormStatus.available {
                        self.loadForm()
                    }
                }
            })
        
    }
    
    func loadForm() {
        UMPConsentForm.load(completionHandler: { form, loadError in
            if loadError != nil {
                // Handle the error.
            } else {
                // Present the form. You can also hold on to the reference to present
                // later.
                if UMPConsentInformation.sharedInstance.consentStatus == UMPConsentStatus.required {
                    form?.present(
                        from: self,
                        completionHandler: { dismissError in
                            if UMPConsentInformation.sharedInstance.consentStatus == UMPConsentStatus.obtained {
                                // App can start requesting ads.
                                if let callback = self.canLoadAdsCallback {
                                    callback()
                                }
                            }
                            // Handle dismissal by reloading form.
                            self.loadForm();
                        })
                } else {
                    // Keep the form available for changes to user consent.
                }
            }
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Your existing code and UI setup here
}

struct UMPWrapper: UIViewControllerRepresentable {
    var canLoadAdsCallback: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UMPViewController {
        let umpViewController = UMPViewController()
        umpViewController.canLoadAdsCallback = canLoadAdsCallback
        return umpViewController
    }
    
    func updateUIViewController(_ uiViewController: UMPViewController, context: Context) {
        
    }
}
