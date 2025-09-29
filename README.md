# Vendor Distance Explorer

A Flutter experience for discovering vendor partners across India, featuring a polished OpenStreetMap interface, smart distance insights, and Google Maps handoff for turn-by-turn navigation.

## Features
- 🌐 **OpenStreetMap visuals** rendered with `flutter_map` for crisp, responsive cartography across platforms.
- 📍 **Dynamic user pin** – hold anywhere on the map to reposition your starting point and instantly refresh nearby distances.
- 🗂️ **Apps Script data source** – vendor details are fetched from the provided Google Apps Script endpoint.
- 🧭 **Real-time distance & ETA** – lightweight API calls estimate how far each vendor is from your current pin.
- 🧾 **Rich vendor panels** – elegant cards and bottom sheets highlight contact details and actionable context.
- 🚘 **Launch Google Maps** for guided navigation from your chosen anchor point to the selected vendor.

## Getting started
1. Ensure you have Flutter 3.13 or later installed.
2. Fetch packages:
   ```bash
   flutter pub get
   ```
3. Run on your desired platform:
   ```bash
   flutter run
   ```

### Platform setup notes
- **Android** – location permission prompts are handled via `geolocator`. Make sure to update the application id in `android/app/build.gradle` if needed.
- **iOS** – adjust the descriptive copy for location usage inside `Info.plist` to match your distribution needs.
- **Web/Desktop** – no additional configuration is required beyond enabling location access in the browser/OS.

## Architecture
- `lib/main.dart` hosts the presentation layer: responsive layout, themed widgets, map configuration, and user interactions.
- `lib/models/vendor.dart` describes the vendor domain model.
- `lib/services/` encapsulates HTTP access to the Apps Script endpoints and geolocation utilities.
- `lib/widgets/vendor_bottom_sheet.dart` renders the polished details surface with navigation actions.

## Environment variables
No secret keys are required. All external calls target the provided Apps Script endpoint.

## Assets
The project avoids raster assets (PNG/JPG) to keep the repo lightweight and source-control friendly.
