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

## 📸 Interface Preview

| Dashboard & Financials | Inventory & IMEI Tracking | Service & Repair Tickets |
| :---: | :---: | :---: |
| <img src="assets/screenshots/dashboard.png" width="240" alt="Dashboard Screen" /> | <img src="assets/screenshots/inventory.png" width="240" alt="Inventory Screen" /> | <img src="assets/screenshots/repairs.png" width="240" alt="Repairs Screen" /> |

| Customer & Vendor Khata | Printable Job Slip | Point of Sale (POS) |
| :---: | :---: | :---: |
| <img src="assets/screenshots/ledgers.png" width="240" alt="Ledger Accounts Screen" /> | <img src="assets/screenshots/intake_slip.png" width="240" alt="Repair Slip Modal" /> | <img src="assets/screenshots/pos.png" width="240" alt="POS Screen" /> |

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
