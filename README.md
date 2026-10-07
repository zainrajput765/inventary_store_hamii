# Hami Mobiles ERP 📱⚡

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

A cross-platform Enterprise Resource Planning (ERP) application engineered for smartphone retail outlets, wholesale traders, and mobile repair labs. Built with **Flutter**, an offline-first **Isar** local database, and **Firebase** cloud synchronization.

---

## 📌 Problem & Solution

Retail mobile shops and hardware repair labs face constant operational bottlenecks:
- Misplaced paper job sheets and repair intake slips.
- Untracked replacement parts leaking inventory value.
- Untracked customer credit balances (*Khata*) and delayed vendor settlements.
- Unreliable internet causing point-of-sale downtime.

**Hami Mobiles ERP** unifies hardware intake, parts inventory, financial ledgers, and sales checkout into a fast, offline-capable mobile workflow.

---



## ✨ Features & Modules

### 📦 1. Inventory & Device Tracking
- **Categorized Catalogs:** Manage stock across New Devices, Pre-Owned Phones, Accessories, and Spare Parts (Screens, Batteries, ICs, Charging Ports).
- **IMEI / Serial Traceability:** Track high-value devices individually across vendor purchase, repair history, and final sale.
- **Low-Stock Triggers:** Visual thresholds alert technicians when critical parts reach minimum levels.

### 🛠️ 2. Service & Repair Lifecycle
- **5-Stage Pipeline:** `Received` ➔ `Diagnosed` ➔ `Customer Approval` ➔ `In Repair` ➔ `Delivered`.
- **Automatic Part Deduction:** Spare parts used during service are automatically debited from the shop inventory.
- **Printable Repair Slips:** Generates printable receipts (58mm/80mm thermal and standard paper) with unique Job IDs, issue descriptions, and estimated charges.

### 📒 3. Digital Ledger & Khata Accounting
- **Customer & Vendor Accounts:** Real-time debit and credit balances with full transaction audit trails.
- **Flexible Settlements:** Supports full payments, cash advances, partial dues, and online transfers.
- **Statement Exports:** Generates customer balance sheets and financial reports in PDF format.

### ⚡ 4. Offline-First Synchronization
- **Zero Latency:** High-speed reads and writes via local database storage guarantee zero slowdowns on the shop counter.
- **Background Cloud Sync:** Automatically reconciles local records with Firebase Firestore whenever internet connectivity is available.

---

## 🏗️ Architecture

The codebase follows a clean, feature-first layered architecture:

```text
lib/
├── core/
│   ├── constants/             # App colors, typography, layout metrics
│   ├── errors/                # Failures and exception handlers
│   ├── services/              # Local DB driver, network sync, print engine
│   ├── theme/                 # Dark and light visual themes
│   └── utils/                 # Currency formatters, date helpers, validators
├── features/
│   ├── auth/                  # Authentication, PIN lock, technician roles
│   ├── dashboard/             # Overview metrics, daily revenue, active repairs
│   ├── inventory/             # Stock catalog, IMEI scanner, stock intake
│   ├── ledgers/               # Customer & vendor Khata balances, payment logging
│   ├── repairs/               # Job tickets, status transitions, parts association
│   └── sales/                 # Cash counter, POS receipts, discount management
├── app.dart                   # Root MaterialApp and routing setup
└── main.dart                  # Dependency injection and entry point

## 🛠️ Tech Stack

* **UI Framework:** Flutter (Dart 3+)
* **State Management:** Provider / BLoC
* **Local Database:** Isar Database (Embedded NoSQL)
* **Backend & Cloud Sync:** Firebase Authentication, Cloud Firestore, Firebase Storage
* **Receipt & Document Generation:** `pdf`, `printing`
* **Barcode & Hardware Access:** `mobile_scanner`, `image_picker`

---

## 🚀 Getting Started

### Prerequisites

Ensure your development environment meets these requirements:

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`v3.19.0` or higher)
* [Dart SDK](https://dart.dev/get-dart)
* Android Studio / VS Code with Flutter extension
* [Firebase CLI](https://firebase.google.com/docs/cli) installed and authenticated

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/hami-mobiles-erp.git](https://github.com/your-username/hami-mobiles-erp.git)
   cd hami-mobiles-erp
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**  
   Run the FlutterFire configuration tool to generate platform-specific credentials:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

4. **Run Code Generation:**  
   Generate database schemas and model adapters:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Launch the application:**
   ```bash
   flutter run
   ```

---

## 🔒 Configuration & Best Practices

* Add `google-services.json` and `GoogleService-Info.plist` to your `.gitignore` to protect production API keys.
* Enforce Firestore Security Rules so only authenticated shop accounts can access ledger and inventory data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 🤝 Contributing

Contributions and feature suggestions are welcome!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/NewFeature`)
3. Commit your Changes (`git commit -m 'feat: Add NewFeature'`)
4. Push to the Branch (`git push origin feature/NewFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.

---

## 👨‍💻 Author

**Zain Rajput**

* **GitHub:** [@zainrajput765](https://github.com/zainrajput765)
* **LinkedIn:** [Zain Rajput](https://www.linkedin.com/in/zain-rajput765/)




