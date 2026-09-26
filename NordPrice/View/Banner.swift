//
//  Banner.swift
//  NordPrice
//
//  Created by Martin Pihooja on 08.02.2023.
//

import SwiftUI
import GoogleMobileAds
import UIKit

struct AdaptiveBannerAd: View {
    let unitID: String
    @ObservedObject private var consent = ConsentManager.shared
    /// Height of the loaded ad; 0 until one arrives.
    @State private var adHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            AdaptiveBannerRepresentable(
                unitID: unitID,
                width: geo.size.width,
                canRequestAds: consent.canRequestAds,
                onAdLoaded: { height in
                    withAnimation(.easeInOut(duration: 0.25)) { adHeight = height }
                }
            )
        }
        // Collapsed until an ad actually arrives, so on "No fill" (or before consent)
        // the content above takes the space instead of leaving an empty gap. Giving
        // the view an exact height also stops the GeometryReader from swallowing all
        // leftover space in the parent stack.
        .frame(height: adHeight)
        .clipped()
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let unitID: String
    let width: CGFloat
    let canRequestAds: Bool
    let onAdLoaded: (CGFloat) -> Void

    /// Inline adaptive ads are never taller than this.
    static let maxAdHeight: CGFloat = 50

    #if DEBUG
    private var resolvedUnitID: String { "ca-app-pub-3940256099942544/2934735716" } // test banner
    #else
    private var resolvedUnitID: String { unitID }
    #endif

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = resolvedUnitID
        // Left nil on purpose: the SDK then presents click-throughs from the view
        // controller that actually contains the banner. A detached UIViewController
        // is not in the window hierarchy and cannot present anything.
        banner.delegate = context.coordinator
        // BannerView reports its adSize as intrinsic content size. With the default
        // priorities that size wins over SwiftUI's proposal, so an ad sized during a
        // transient layout pass would keep the banner wider than the screen.
        banner.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        banner.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return banner
    }

    /// Always take exactly the space SwiftUI offers, never the ad's intrinsic size.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BannerView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? width, height: proposal.height ?? Self.maxAdHeight)
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        context.coordinator.onAdLoaded = onAdLoaded

        // Requesting before UMP consent is gathered only yields limited ads.
        guard width > 0, canRequestAds else { return }

        // Avoid reloading if width didn't really change
        if abs(width - context.coordinator.lastLoadedWidth) < 1 { return }
        context.coordinator.lastLoadedWidth = width

        // Use the returned AdSize as-is: its flags mark it as adaptive. Rebuilding it
        // from `.size` alone yields an invalid custom size ("Invalid ad width or height").
        // Inline adaptive keeps the full width but caps the height; the SDK picks the
        // actual height (at most maxAdHeight) when the ad loads.
        banner.adSize = inlineAdaptiveBanner(width: width, maxHeight: Self.maxAdHeight)

        banner.load(Request())
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var lastLoadedWidth: CGFloat = 0
        var onAdLoaded: ((CGFloat) -> Void)?

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            // For inline adaptive the SDK updates adSize to the served ad's real size.
            let maxHeight = AdaptiveBannerRepresentable.maxAdHeight
            let reported = bannerView.adSize.size.height
            let height = reported > 0 ? min(reported, maxHeight) : maxHeight
            print("✅ Adaptive banner loaded (\(Int(height)) pt)")
            onAdLoaded?(height)
        }

        // A failed refresh keeps the previous ad on screen, so the banner is not
        // collapsed here; it only stays hidden if no ad has loaded yet.
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Adaptive banner failed: \(error.localizedDescription)")
        }
    }
}
