//
//  Banner.swift
//  NordPrice
//
//  Created by Martin Pihooja on 08.02.2023.
//

import SwiftUI
import GoogleMobileAds
import UIKit

/// Bottom banner for one of the tabs.
///
/// A banner only exists while its own tab is what the user is looking at, and it only
/// requests while the app is foregrounded. Both matter: a `BannerView` that stays alive
/// keeps refreshing into its ad unit whether anyone can see it or not, and AdMob answers
/// those invisible requests with no-fills and unwinnable auctions. The home unit was at
/// ~7 requests per impression and a 48% match rate because of it, while the low-volume
/// settings unit — one request per visit, always on screen — matched 94% and earned
/// nearly 3x the eCPM.
struct AdaptiveBannerAd: View {
    let unitID: String
    /// Tab indices this banner is on. A set because the iPad dashboard answers both the
    /// today and the tomorrow index (`TabBarView.tabSelection`).
    let tabs: Set<Int>
    /// Ceiling for this placement. Google serves an ad no taller than this and never
    /// shorter than the classic 50 pt banner, so a generous ceiling costs nothing when the
    /// auction returns a small ad — the space reserved below follows the served height.
    /// Ask per screen: a screen whose chart must stay readable (Today) gets a small value,
    /// a screen that scrolls or has empty space to fill gets a large one.
    let maxHeight: CGFloat

    @ObservedObject private var consent = ConsentManager.shared
    @ObservedObject private var navigation = AppNavigation.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Height of the loaded ad; 0 until one arrives. Deliberately held here rather than in
    /// the representable, so it survives the tab switches that tear the view down — the
    /// space stays reserved and the screen does not reflow when the user comes back.
    @State private var adHeight: CGFloat = 0

    var body: some View {
        Group {
            if tabs.contains(navigation.selectedTab) {
                GeometryReader { geo in
                    AdaptiveBannerRepresentable(
                        unitID: unitID,
                        width: geo.size.width,
                        maxHeight: maxHeight,
                        // Requesting before UMP consent is gathered only yields limited ads.
                        // Going inactive keeps the current ad on screen and only pauses the
                        // cadence, so a quick trip to Control Center costs no request.
                        canRequestAds: scenePhase == .active && consent.canRequestAds,
                        onAdLoaded: { height in
                            withAnimation(.easeInOut(duration: 0.25)) { adHeight = height }
                        }
                    )
                }
            }
        }
        // Same width as the price cards and the chart, so the ad does not stick out past
        // them. On the iPad layouts `cardWidth` is nil and the banner fills its container.
        .cardWidth()
        .frame(height: adHeight)
        .clipped()
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let unitID: String
    let width: CGFloat
    let maxHeight: CGFloat
    let canRequestAds: Bool
    let onAdLoaded: (CGFloat) -> Void

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
        CGSize(width: proposal.width ?? width, height: proposal.height ?? maxHeight)
    }

    static func dismantleUIView(_ banner: BannerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onAdLoaded = onAdLoaded
        coordinator.width = width
        coordinator.maxHeight = maxHeight
        coordinator.canRequestAds = canRequestAds
        coordinator.refresh(banner, unit: resolvedUnitID)
    }

    /// Owns the request cadence: one request per appearance, then one per interval, never
    /// more. A failed load is retried on the next tick rather than immediately, so a
    /// no-fill cannot turn into a request storm.
    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {
        private weak var banner: BannerView?
        private var timer: Timer?
        private var spacingTimer: Timer?
        private var lastRequest: Date?
        /// Size the requested ad was sized for; a change means a new request is needed.
        private var requestedWidth: CGFloat = 0
        private var requestedMaxHeight: CGFloat = 0
        private var unitID: String = ""

        var onAdLoaded: ((CGFloat) -> Void)?
        var width: CGFloat = 0
        /// Height ceiling for this placement, handed down by the view.
        var maxHeight: CGFloat = 50
        var canRequestAds = false

        /// Reload cadence while this banner is on the visible tab and the app is active.
        private static let refreshInterval: TimeInterval = 60
        /// Last request per ad unit, shared by every instance: a coordinator is rebuilt on
        /// each tab switch, so per-instance state cannot space out requests that share a unit.
        private static var lastRequestByUnit: [String: Date] = [:]
        /// AdMob expects no more than roughly one request per 10 s per ad unit.
        private static let requestSpacing: TimeInterval = 10

        func refresh(_ banner: BannerView, unit: String) {
            self.banner = banner
            unitID = unit
            armTimer()
            guard canRequestAds else { return }

            let height = maxHeight
            let sizeChanged = abs(width - requestedWidth) >= 1 || abs(height - requestedMaxHeight) >= 1
            let stale = lastRequest.map { Date().timeIntervalSince($0) >= Self.refreshInterval } ?? true
            guard sizeChanged || stale else { return }

            // Keep whatever is on screen and come back for the new size once the unit has
            // had its rest, rather than firing a request per tab switch.
            let since = Self.lastRequestByUnit[unit].map { Date().timeIntervalSince($0) } ?? .infinity
            if since < Self.requestSpacing {
                armSpacingRetry(banner, after: Self.requestSpacing - since)
                return
            }
            request(banner, height: height)
        }

        /// Called when SwiftUI drops the banner (tab switched away): no refreshes without
        /// a banner on screen.
        func stop() {
            timer?.invalidate()
            timer = nil
            spacingTimer?.invalidate()
            spacingTimer = nil
            banner?.delegate = nil
        }

        private func request(_ banner: BannerView, height: CGFloat) {
            requestedWidth = width
            requestedMaxHeight = height
            lastRequest = Date()
            if !unitID.isEmpty { Self.lastRequestByUnit[unitID] = Date() }

            // Use the returned AdSize as-is: its flags mark it as adaptive. Rebuilding it
            // from `.size` alone yields an invalid custom size ("Invalid ad width or height").
            // Inline adaptive keeps the full width but caps the height; the SDK picks the
            // actual height (at most the cap) when the ad loads.
            banner.adSize = inlineAdaptiveBanner(width: width, maxHeight: height)
            banner.load(Request())
        }

        /// One-shot retry once the unit's 10 s spacing has passed.
        private func armSpacingRetry(_ banner: BannerView, after delay: TimeInterval) {
            spacingTimer?.invalidate()
            spacingTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.canRequestAds, let banner = self.banner else { return }
                    self.request(banner, height: self.maxHeight)
                }
            }
        }

        /// Runs only while the app is active and the tab is showing; `refresh(_:unit:)`'s
        /// age check catches up on the way back.
        private func armTimer() {
            if !canRequestAds {
                timer?.invalidate()
                timer = nil
                return
            }
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.canRequestAds, let banner = self.banner else { return }
                    self.request(banner, height: self.maxHeight)
                }
            }
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            // For inline adaptive the SDK updates adSize to the served ad's real size.
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
