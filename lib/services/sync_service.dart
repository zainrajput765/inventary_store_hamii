import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_service.dart';
import '../models/schema.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncService extends ChangeNotifier {
  final DbService dbService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SyncStatus status = SyncStatus.idle;
  String? lastError;
  Timer? _timer;

  // LOCK: Prevents Cloud from overwriting Local data before we upload our changes
  bool _isInitialSyncCompleted = false;

  SyncService(this.dbService);

  // --- REAL-TIME SYNC ENGINE ---
  void startRealtimeSync() {
    // 1. Listen for Internet Connection
    Connectivity().onConnectivityChanged.listen((results) {
      // Handle both list and single result for compatibility
      bool isConnected = false;
      if (results is List) {
        isConnected = !results.contains(ConnectivityResult.none);
      } else {
        isConnected = results != ConnectivityResult.none;
      }

      if (isConnected) {
        forceSync();
      }
    });

    // 2. Poll every 5 minutes (Backup)
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      forceSync();
    });

    // 3. LISTEN TO CLOUD CHANGES (Push Notification Style)
    // We only apply these AFTER we have successfully synced our local state at least once.
    _listenToCollection("products", (list) => _safeMerge(() => dbService.mergeProductsFromCloud(list)));
    _listenToCollection("transactions", (list) => _safeMerge(() => dbService.mergeTransactionsFromCloud(list)));
    _listenToCollection("parties", (list) => _safeMerge(() => dbService.mergePartiesFromCloud(list)));
    _listenToCollection("invoices", (list) => _safeMerge(() => dbService.mergeInvoicesFromCloud(list)));
    _listenToCollection("payment_accounts", (list) => _safeMerge(() => dbService.mergePaymentAccountsFromCloud(list)));
    _listenToCollection("mobile_items", (list) => _safeMerge(() => dbService.mergeMobileItemsFromCloud(list)));
    _listenToDoc("app_settings", "config", (map) => _safeMerge(() => dbService.mergeAppSettingsFromCloud(map)));
  }

  // Wrapper to respect the Lock
  void _safeMerge(Function action) {
    if (_isInitialSyncCompleted && !dbService.isProcessingCloudData) {
      action();
    }
  }

  void _listenToCollection(String collection, Function(List<Map<String, dynamic>>) mergeFunc) {
    _firestore.collection(collection).snapshots().listen((snapshot) {
      if (FirebaseAuth.instance.currentUser != null && snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> list = snapshot.docs.map((d) => d.data()).toList();
        mergeFunc(list);
      }
    });
  }

  void _listenToDoc(String collection, String docId, Function(Map<String, dynamic>) mergeFunc) {
    _firestore.collection(collection).doc(docId).snapshots().listen((doc) {
      if (FirebaseAuth.instance.currentUser != null && doc.exists && doc.data() != null) {
        mergeFunc(doc.data()!);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> forceSync() async {
    if (status == SyncStatus.syncing) return;

    // Stop if Offline Mode (Local PIN)
    if (FirebaseAuth.instance.currentUser == null) return;

    // LOCK: Stop Listeners from interfering
    dbService.isProcessingCloudData = true;
    status = SyncStatus.syncing;
    notifyListeners();

    try {
      var connectivity = await Connectivity().checkConnectivity();
      bool isOffline = false;
      if (connectivity is List) {
        isOffline = connectivity.contains(ConnectivityResult.none);
      } else {
        isOffline = connectivity == ConnectivityResult.none;
      }

      if (isOffline) {
        status = SyncStatus.offline;
        dbService.isProcessingCloudData = false;
        notifyListeners();
        return;
      }

      // 1. UPLOAD LOCAL DATA FIRST (Priority)
      // This ensures our Sales/Deletes overwrite the old Cloud data
      await _uploadData("products", await dbService.getAllProductsForSync());
      await _uploadData("transactions", await dbService.getAllTransactionsForSync());
      await _uploadData("parties", await dbService.getAllPartiesForSync());
      await _uploadData("invoices", await dbService.getAllInvoicesForSync());
      await _uploadData("payment_accounts", await dbService.getAllPaymentAccountsForSync());
      await _uploadData("mobile_items", await dbService.getAllMobileItemsForSync());

      final settings = await dbService.getAppSettingsForSync();
      if(settings != null) await _uploadDoc("app_settings", "config", settings.toMap());

      // 2. FETCH CLOUD DATA (Backup check)
      // Now that we've uploaded, it's safe to download updates from others
      await Future.wait([
        _fetchAndMerge("products", (list) => dbService.mergeProductsFromCloud(list)),
        _fetchAndMerge("transactions", (list) => dbService.mergeTransactionsFromCloud(list)),
        _fetchAndMerge("parties", (list) => dbService.mergePartiesFromCloud(list)),
        _fetchAndMerge("invoices", (list) => dbService.mergeInvoicesFromCloud(list)),
        _fetchAndMerge("payment_accounts", (list) => dbService.mergePaymentAccountsFromCloud(list)),
        _fetchAndMerge("mobile_items", (list) => dbService.mergeMobileItemsFromCloud(list)),
        _fetchDocAndMerge("app_settings", "config", (map) => dbService.mergeAppSettingsFromCloud(map)),
      ]).timeout(const Duration(seconds: 20));

      // UNLOCK: Sync is safe, listeners can resume
      _isInitialSyncCompleted = true;
      status = SyncStatus.success;
      lastError = null;

    } catch (e) {
      status = SyncStatus.error;
      lastError = e.toString();
      debugPrint("Sync Error: $e");
    } finally {
      dbService.isProcessingCloudData = false;
      notifyListeners();
    }
  }

  // --- HELPER: Upload Logic (FIXED: BATCH CHUNKING) ---
  Future<void> _uploadData(String collection, List<dynamic> items) async {
    // Firestore batch limit is 500 operations. We split into chunks of 400 to be safe.
    const int chunkSize = 400;

    for (var i = 0; i < items.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      final chunk = items.sublist(i, end);

      for (var item in chunk) {
        String rawId;

        if (item is Product) {
          rawId = item.isMobile ? "${item.name}_${item.imei}" : "${item.name}_${item.brand}";
        } else if (item is Transaction) {
          rawId = "${item.date.millisecondsSinceEpoch}_${item.amount}";
        } else if (item is PaymentAccount) {
          rawId = item.name;
        } else if (item is Party) {
          rawId = "${item.name}_${item.phone}";
        } else if (item is Invoice) {
          rawId = item.invoiceNumber;
        } else if (item is MobileItem) {
          rawId = item.imei;
        } else {
          rawId = item.id.toString();
        }

        String safeId = rawId.replaceAll('/', '_').replaceAll('\\', '_');
        final docRef = _firestore.collection(collection).doc(safeId);
        batch.set(docRef, item.toMap());
      }
      // Commit chunk
      await batch.commit();
    }
  }

  Future<void> _uploadDoc(String collection, String docId, Map<String, dynamic> data) async {
    await _firestore.collection(collection).doc(docId).set(data);
  }

  Future<void> _fetchAndMerge(String collection, Function(List<Map<String, dynamic>>) mergeFunc) async {
    final snapshot = await _firestore.collection(collection).get();
    final data = snapshot.docs.map((d) => d.data()).toList();
    await mergeFunc(data);
  }

  Future<void> _fetchDocAndMerge(String collection, String docId, Function(Map<String, dynamic>) mergeFunc) async {
    final doc = await _firestore.collection(collection).doc(docId).get();
    if (doc.exists && doc.data() != null) {
      await mergeFunc(doc.data()!);
    }
  }
}