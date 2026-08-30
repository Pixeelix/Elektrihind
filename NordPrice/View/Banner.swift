//
//  Banner.swift
//  NordPrice
//
//  Created by Martin Pihooja on 08.02.2023.
//

import SwiftUI
import GoogleMobileAds
import UIKit

struct FixedBannerAd: UIViewRepresentable {
    let unitID: String

    #if DEBUG
    private var resolvedUnitID: String { "ca-app-pub-3940256099942544/2934735716" } // test banner
    #else
    private var resolvedUnitID: String { unitID }
    #endif

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner) // 320x50
        banner.adUnitID = resolvedUnitID
        banner.rootViewController = context.coordinator.viewController
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // fixed size: nothing to update
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let viewController = UIViewController()

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Fixed banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Fixed banner failed: \(error.localizedDescription)")
        }
    }
}



struct AdaptiveBannerAd: View {
    let unitID: String

    var body: some View {
        GeometryReader { geo in
            AdaptiveBannerRepresentable(unitID: unitID, width: geo.size.width)
        }
        // IMPORTANT:
        // Don't hard-cap this if you want true adaptive (it can be 50–90).
        // If you *do* cap it, it may clip on iPad/landscape.
        .frame(minHeight: 50) // lets it expand if needed
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let unitID: String
    let width: CGFloat

    #if DEBUG
    private var resolvedUnitID: String { "ca-app-pub-3940256099942544/2934735716" } // test banner
    #else
    private var resolvedUnitID: String { unitID }
    #endif

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = resolvedUnitID
        banner.rootViewController = context.coordinator.viewController
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard width > 0 else { return }

        // Avoid reloading if width didn't really change
        if abs(width - context.coordinator.lastLoadedWidth) < 1 { return }
        context.coordinator.lastLoadedWidth = width

        // Anchored adaptive size for this width
        // If your SDK exposes a different helper name, tell me and I’ll map it.
        let gadAdSize = currentOrientationAnchoredAdaptiveBanner(width: width)

        // Convert to the Swift AdSize wrapper you're using
        banner.adSize = AdSize(size: gadAdSize.size, flags: 0)

        banner.load(Request())
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let viewController = UIViewController()
        var lastLoadedWidth: CGFloat = 0

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Adaptive banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Adaptive banner failed: \(error.localizedDescription)")
        }
    }
} 
