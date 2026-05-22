# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NordPrice is a SwiftUI iOS app that displays Nord Pool electricity prices for Baltic states and Finland. It includes a WidgetKit extension for home/lock screen widgets. The app fetches 15-minute interval price data from Elering's API and displays it as bar charts with current price highlights.

## Build & Run

- **Open**: `Elektrihind.xcworkspace` (not .xcodeproj — CocoaPods workspace)
- **Install dependencies**: `pod install` (requires CocoaPods)
- **Min deployment**: iOS 16.0
- **Targets**: `NordPrice` app product (Xcode target `Elektrihind`), `NordPriceWidgetExtensionExtension` widget product (Xcode target `ElektrihindWidgetExtensionExtension`)
- **No test targets** exist in this project

## Architecture

**MVVM with SwiftUI** — `@StateObject`/`@ObservedObject` for reactive state, async/await for networking.

### Data Flow

`NordPriceApp` → Firebase/ATT/UMP init → `ContentView` (network check) → `TabBarView` (3 tabs: Today, Tomorrow, Settings)

Each price view uses:
- `ChartViewModel` — loads full-day price data, computes min/max/avg
- `CurrentPriceViewModel` — current price with quarter-hour timer refresh
- `NetworkService` — fetches from `dashboard.elering.ee/api/nps/price`, caches complete daily data

### Shared State

- `Globals` (`@Observable`) — user preferences (region, language, unit, tax, chart resolution) synced to widget via App Groups (`group.koodipardik.Elektrihind`)
- Price cache uses versioned UserDefaults keys: `prices_v1_<region>_<utcStartTime>`
- Widget reads shared cache and settings from App Group UserDefaults

### Key Modules

- `Elektrihind/Models/` — `Globals`, `NordPoolPrice` (API response models), `SharedLocalization`
- `Elektrihind/Network/NetworkManager.swift` — connectivity monitor + `NetworkService` with DST-aware UTC interval calculation (handles 23/24/25-hour days)
- `Elektrihind/View/` — SwiftUI views + view models + AdMob banner
- `Elektrihind/BarChartView/` — custom bar chart components
- `ElektrihindWidgetExtension/` — single-file widget with SwiftUI Charts (LineMark), supports systemSmall & systemMedium

### Price Units

API returns €/MWh. Display converts based on user setting: €/kWh (÷1000), €/MWh (÷1), or cent/kWh (÷10), with optional region-specific VAT (EE 24%, LV 21%, LT 21%, FI 25.5%).

### Localization

4 languages: Estonian, English, Finnish, Russian. Region auto-detected from device locale. Localization via `.localized()` String extension and Localizable.xcstrings.

## Dependencies (CocoaPods)

- Firebase/Analytics, Google-Mobile-Ads-SDK (AdMob), FBAudienceNetwork, GoogleMobileAdsMediationFacebook, GoogleUserMessagingPlatform (UMP/GDPR consent)
- Static linking enabled (`use_frameworks! :linkage => :static`)
