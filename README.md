# sagansa

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Widget iOS (Dashboard Sagansa)

App ini meng-host **WidgetKit extension** `SagansaWidgetExtension` (folder
`ios/SagansaWidget`) yang menampilkan KPI Sales Dashboard (Omzet/Order/Qty +
delta + tren) di home screen, tanpa membuka app.

- **Cara kerja**: `WidgetBridge` (`lib/services/widget_bridge.dart`) menulis
  token Sanctum + role ke App Group `group.id.sagansa.app` via paket
  `home_widget` setiap auth berubah (login/logout/startup). Extension membaca
  token lalu fetch `GET /sales-dashboard` sendiri tiap ±30 menit + saat tombol
  periode/metrik di widget ditekan (interaktif).
- **UI & logic widget** ada di package Swift bersama:
  `mobiles/sagansa-widget-shared` — dipakai juga oleh companion macOS
  (`mobiles/sagansa-widget-macos`).
- **Minimum iOS: 27.0** (host app + extension; app internal — armada iPhone
  11/2019+ yang didukung iOS 27).
- Build biasa (`flutter build ios` / run dari Xcode) otomatis ikut mem-build
  extension — verifikasi: `build/ios/iphoneos/Runner.app/PlugIns/SagansaWidgetExtension.appex`.
- Perangkat fisik butuh App Group aktif di signing team (Xcode → Runner →
  Signing & Capabilities → App Group `group.id.sagansa.app`; ditambahkan
  otomatis oleh automatic signing).
- Desain lengkap: `docs/superpowers/specs/2026-09-20-sagansa-dashboard-widget-ios-macos-design.md`
  (di root repo).

