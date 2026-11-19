# Sagansa — App Review Information (Guideline 2.1 Reply)

> Paste konten di bawah ini ke **App Store Connect → App Review Information →
> Notes** (dan kirim ulang untuk review). Isi bagian `[BRACKET]` sebelum submit.
> Ditulis dalam bahasa Inggris karena dibaca oleh App Store reviewer.

---

**Sagansa** is a business-operations and point-of-sale (POS) platform for
restaurants, retail stores, and service businesses in Indonesia. The iOS app is
a companion to the Sagansa web platform (sagansa.id). This submission is the
first public release of the app.

### 1. Screen recording

A screen recording captured on a physical iPhone running the latest iOS will be
attached with this submission. It begins by launching the app and walks through
the core user flow:

1. **Launch** — splash screen, then the login screen.
2. **Login** — sign in with an email/password account provisioned on the
   Sagansa web platform (staff accounts are created by the business owner).
3. **Home dashboard** — summary of today's sales, presence, and outstanding
   tasks.
4. **POS (Kasir)** — create a sales transaction and generate a receipt.
5. **Attendance (Presensi)** — check-in/check-out. This demonstrates the
   location permission prompt (When In Use) and the camera permission prompt
   (attendance photo), both of which the recording will show when triggered.
6. **Inventory (Stok)** — view product list and stock levels.
7. **Notifications** — open the notification list (Firebase Cloud Messaging).

Notes for the recording:

- **Account registration:** registration is not available inside the app;
  business accounts and staff accounts are created on the web platform
  (sagansa.id) and staff log in with credentials provided by their employer.
- **Account deletion:** the app does not create accounts and therefore has no
  in-app account deletion flow. Account data deletion is handled by the
  business owner through the Sagansa admin web panel or by contacting
  support@sagansa.id. The app only displays data owned by the logged-in
  business; it contains no public user-generated content, so there are no
  content-reporting or blocking features.
- **Paid content / IAP:** the app contains no in-app purchases, subscriptions,
  or access to paid digital content. POS transactions are physical
  goods/services paid outside the app.
- **Sensitive permissions:** the recording shows the location (When In Use) and
  camera permission prompts as they appear during attendance. The app does not
  request Bluetooth, microphone, contacts, calendar, or App Tracking
  Transparency (no tracking / no IDFA).

### 2. Devices and operating systems tested

- iPhone 15 Pro Max — iOS 18.x
- iPhone 14 — iOS 17.x
- iPhone 13 — iOS 17.x
- iPhone SE (2nd gen) — iOS 16.x
- iPad (10th gen) — iPadOS 17.x

Minimum supported OS: **iOS 16.0 / iPadOS 16.0** (see Info.plist deployment
target). The app supports iPhone and iPad.

`[UPDATE with the exact devices/OS you actually tested before submission.]`

### 3. App function and target audience

**Problem it solves:** Small and medium businesses (MSMEs) in Indonesia —
especially restaurants, retail stores, and service businesses — juggle several
disconnected tools for selling, tracking stock, managing staff attendance, and
handling finances. Sagansa unifies these daily operations in a single app so a
business owner or manager can run the whole business from one place, with
consistency across multiple branches.

**Value it provides:**

- **Point of Sale (Kasir):** fast sales transactions with receipt printing
  (including thermal sticker / label printing over the local network).
- **Inventory & stock:** warehouse stock tracking, low-stock awareness, stock
  transfers between branches, and stock audits.
- **Employee attendance:** location-verified check-in/check-out, shift
  scheduling, leave requests, and salary records.
- **Purchasing & procurement:** supplier management, purchase requests,
  payment receipts.
- **Sales orders:** online order intake, employee sales, and delivery status
  tracking.
- **Finance:** income/expense records, per-shift cash reconciliation, and
  business reports.
- **Assets & maintenance:** asset registry, periodic check reminders, and
  issue reporting.
- **Additional operational modules:** hygiene checklists, utility usage
  tracking, fuel service records, production and recipes.

**Target audience:** business owners, store managers, supervisors, warehouse
staff, and sales employees of Indonesian MSMEs and multi-branch businesses
(retail, food & beverage, services, distribution).

### 4. Setup instructions for main features

1. **Create an account:** sign up at https://sagansa.id (web). The business
   owner creates staff accounts or invites staff by email. There is no
   self-registration inside the app.
2. **Login:** open the app, enter the email and password provided by the
   business owner, and tap Login.
3. **Take a sale:** open the POS (Kasir) tab, add products, complete the
   transaction, and print a receipt if a printer is configured.
4. **Clock in:** open the Attendance (Presensi) tab, grant location and camera
   access when prompted, and tap Check-in. Check-out works the same way.
5. **Manage stock:** open the Stok tab to view inventory, create stock
   transfers between branches, and review stock movements.
6. **Printer setup (optional):** Settings → Sticker Printer lets the user point
   the app at an ESC/POS thermal printer on the local network (IP + port 9100).

`[Add a demo login (email/password) or sample data that Apple reviewers can use.
If you do not want to expose real credentials, provision a dedicated review
account and list it here, e.g. "Review account: review@sagansa.id /
<password>".]`

### 5. External services used to deliver core functionality

- **Sagansa API backend** (`https://api.sagansa.id`) — the primary service;
  a Laravel-based REST API providing authentication, sales, inventory,
  presence, salary, procurement, and reporting data. All app functionality
  depends on it.
- **Sagansa image service** (`https://img.sagansa.id`) — stores photos/images
  uploaded from the app (attendance photos, product/asset/document images).
- **Firebase Cloud Messaging** — push notifications (transaction approvals,
  leave status, invoices, operational alerts).
- **Apple location services** (via Geolocator) — used only while the app is in
  the foreground to verify attendance check-in/check-out location.
- **Local network access** — connecting to an ESC/POS thermal printer
  (WiFi/TCP, port 9100) for receipt and label printing; the user's own printer,
  no third-party provider.
- **QR scanning** — QRIS payment code scanning (read-only local scan).
- **Camera and photo library** — for attendance photos and attaching images to
  records.
- **PDF generation & printing** — receipts and documents rendered locally and
  sent to the system print dialog.

Note: the Sagansa web platform (sagansa.id) integrates Xendit and Midtrans for
subscription billing; these are used by the web platform only and are not
part of the iOS app, which contains no payments.

### 6. Regional differences

The app is currently available only in Indonesia, with the UI in Bahasa
Indonesia. Features and content are consistent across all regions; there are no
region-specific feature differences. The app does not process payment
transactions itself.

### 7. Regulated industry / protected third-party material

Not applicable. Sagansa is a general business-operations tool for MSMEs and
does not operate in a regulated industry, does not provide financial,
medical, or legal advice, and does not include any protected third-party
material. All content shown in the app is business data entered by the
customer's own organization.