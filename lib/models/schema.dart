import 'package:isar/isar.dart';

part 'schema.g.dart';

@Collection()
class Product {
  Id id = Isar.autoIncrement;

  late String name;
  late String brand;
  late String category;
  late int quantity;
  late double costPrice;
  late double sellPrice;

  String? ptaStatus;
  @Index()
  String? imei;
  String? color;
  String? memory;
  String? ram;
  String? condition;
  String? batteryHealth;
  bool isMobile = false;

  bool isDeleted = false;
  String? sourceContact;

  // Conflict Resolution
  String? lastAction;
  DateTime? lastActionTime;

  Map<String, dynamic> toMap() {
    return {
      'name': name, 'brand': brand, 'category': category, 'quantity': quantity,
      'costPrice': costPrice, 'sellPrice': sellPrice, 'ptaStatus': ptaStatus,
      'imei': imei, 'color': color, 'memory': memory, 'ram': ram,
      'condition': condition, 'batteryHealth': batteryHealth, 'isMobile': isMobile,
      'sourceContact': sourceContact,
      'isDeleted': isDeleted,
      'lastAction': lastAction,
      'lastActionTime': lastActionTime?.toIso8601String(),
    };
  }
}

@Collection()
class MobileItem {
  Id id = Isar.autoIncrement;
  late int productId;
  late String productName;
  @Index()
  late String imei;
  late String status;
  late double specificCostPrice;

  Map<String, dynamic> toMap() {
    return { 'productId': productId, 'productName': productName, 'imei': imei, 'status': status, 'cost': specificCostPrice };
  }
}

@Collection()
class Party {
  Id id = Isar.autoIncrement;
  late String name;
  late String type;
  late String phone;
  late double balance;

  // NEW: Sync Timer for Ledger
  DateTime? lastActionTime;

  Map<String, dynamic> toMap() {
    return {
      'name': name, 'type': type, 'phone': phone, 'balance': balance,
      'lastActionTime': lastActionTime?.toIso8601String()
    };
  }
}

@Collection()
class Invoice {
  Id id = Isar.autoIncrement;
  late DateTime date;
  @Index()
  late String invoiceNumber;
  late String customerName;
  late double totalAmount;
  late double discount;
  late double finalAmount;
  late double totalCost;
  late String paymentMode;

  Map<String, dynamic> toMap() {
    return { 'date': date.toIso8601String(), 'invoiceNumber': invoiceNumber, 'customerName': customerName, 'totalAmount': totalAmount, 'discount': discount, 'finalAmount': finalAmount, 'totalCost': totalCost, 'paymentMode': paymentMode };
  }
}

@Collection()
class Transaction {
  Id id = Isar.autoIncrement;
  late DateTime date;
  late String type;
  late double amount;
  String? description;
  int? partyId;
  String? partyName;
  String? paymentSource;

  bool isDeleted = false;

  Map<String, dynamic> toMap() {
    return { 'date': date.toIso8601String(), 'type': type, 'amount': amount, 'description': description, 'partyName': partyName, 'paymentSource': paymentSource, 'isDeleted': isDeleted };
  }
}

@Collection()
class AppSettings {
  Id id = Isar.autoIncrement;
  String? adminPin;
  String? staffPin;
  String? backupEmail;

  Map<String, dynamic> toMap() { return { 'adminPin': adminPin, 'staffPin': staffPin, 'backupEmail': backupEmail }; }
}

@Collection()
class PaymentAccount {
  Id id = Isar.autoIncrement;
  late String name;
  late String type;
  bool isDefault = false;
  bool isDeleted = false;

  Map<String, dynamic> toMap() { return { 'name': name, 'type': type, 'isDefault': isDefault, 'isDeleted': isDeleted }; }
}