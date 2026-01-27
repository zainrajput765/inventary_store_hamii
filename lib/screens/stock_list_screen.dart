import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Required for Timer & StreamSubscription
import 'package:connectivity_plus/connectivity_plus.dart'; // Required for Auto-Sync
import '../services/db_service.dart';
import '../models/schema.dart';
import 'edit_product_screen.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import 'scanner_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});
  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final searchCtrl = TextEditingController();
  String searchQuery = "";
  StreamSubscription? _connectivitySubscription;

  // Connectivity State
  bool _isOffline = false;
  bool _isSyncTimeout = false; // Tracks if sync takes too long (30s)
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    // 1. Initial Connectivity Check
    _checkInitialConnectivity();

    // 2. Listen for Connectivity Changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectionState(results);
    });

    // 3. Listen to SyncService Status (To trigger 30s timeout)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = Provider.of<SyncService>(context, listen: false);
      syncService.addListener(_onSyncStatusChanged);

      // Manually call it once to handle initial state
      _onSyncStatusChanged();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _timeoutTimer?.cancel();
    try {
      Provider.of<SyncService>(context, listen: false).removeListener(_onSyncStatusChanged);
    } catch(e) {}
    searchCtrl.dispose();
    super.dispose();
  }

  // --- 30 SECOND TIMEOUT LOGIC ---
  void _onSyncStatusChanged() {
    if (!mounted) return;
    final status = Provider.of<SyncService>(context, listen: false).status;

    if (status == SyncStatus.syncing) {
      // Start timer if not already running
      if (_timeoutTimer == null || !_timeoutTimer!.isActive) {
        _timeoutTimer?.cancel();
        _timeoutTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) {
            setState(() {
              _isSyncTimeout = true; // Show offline icon after 30s
            });
          }
        });
      }
    } else {
      // Stop timer if sync finishes or fails
      _timeoutTimer?.cancel();
      if (_isSyncTimeout) {
        setState(() {
          _isSyncTimeout = false;
        });
      }
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionState(result);
  }

  void _updateConnectionState(List<ConnectivityResult> results) {
    // If 'none' is in the list, we are offline
    bool isOffline = false;
    if (results is List) {
      isOffline = results.contains(ConnectivityResult.none);
    } else {
      isOffline = results == ConnectivityResult.none;
    }

    if (mounted) {
      setState(() {
        _isOffline = isOffline;
        // If net comes back, reset the timeout flag immediately
        if (!isOffline) _isSyncTimeout = false;
      });
    }

    if (!isOffline) {
      // Internet Connected: Trigger Sync Automatically
      final syncService = Provider.of<SyncService>(context, listen: false);
      if (syncService.status != SyncStatus.syncing) {
        syncService.forceSync();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Stock Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.assignment_return_outlined, color: Colors.deepOrange),
              tooltip: "Process Return",
              onPressed: () => _showReturnDialog(context),
            ),

            // --- UPDATED SYNC ICON LOGIC ---
            Consumer<SyncService>(
              builder: (context, syncService, child) {
                // CONDITION 1: Physical Offline OR Sync Timeout (30s)
                if (_isOffline || _isSyncTimeout) {
                  return const IconButton(
                    icon: Icon(Icons.wifi_off, color: Colors.grey),
                    onPressed: null,
                    tooltip: "Offline / Slow Connection",
                  );
                }

                // CONDITION 2: Normal Sync Status
                switch (syncService.status) {
                  case SyncStatus.syncing:
                    return Container(margin: const EdgeInsets.all(14), width: 20, height: 20, child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)));
                  case SyncStatus.success:
                    return IconButton(icon: const Icon(Icons.cloud_done, color: Color(0xFF10B981)), onPressed: () {}, tooltip: "Data Synced");
                  case SyncStatus.error:
                    return IconButton(icon: const Icon(Icons.cloud_off, color: Colors.red), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Error: ${syncService.lastError}"))); syncService.forceSync(); });
                  case SyncStatus.offline:
                    return const IconButton(icon: Icon(Icons.wifi_off, color: Colors.grey), onPressed: null);
                  case SyncStatus.idle:
                  default:
                    return IconButton(icon: const Icon(Icons.cloud_queue, color: Colors.grey), onPressed: () => syncService.forceSync());
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            labelColor: Color(0xFF0F172A),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [Tab(text: "Android"), Tab(text: "iPhone"), Tab(text: "Accessories")],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(hintText: "Search Name, IMEI...", prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                      onChanged: (val) => setState(() => searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, size: 30),
                    color: const Color(0xFF0F172A),
                    onPressed: () async {
                      final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                      if (code != null) {
                        searchCtrl.text = code;
                        setState(() => searchQuery = code);
                      }
                    },
                  )
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  InventoryGrid(category: 'Android', query: searchQuery),
                  InventoryGrid(category: 'iPhone', query: searchQuery),
                  InventoryGrid(category: 'Accessory', query: searchQuery),
                ],
              ),
            ),
            // --- MANUFACTURED BY FOOTER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: const Text(
                "Manufactured by ZEDECH",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- RETURN DIALOG ---
  void _showReturnDialog(BuildContext context) {
    final productCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final imeiCtrl = TextEditingController();

    bool isDealerReturn = false;
    int? selectedPartyId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Process Return"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("Customer Refund")),
                        selected: !isDealerReturn,
                        onSelected: (val) => setState(() => isDealerReturn = false),
                        selectedColor: Colors.green[100],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("Return to Dealer")),
                        selected: isDealerReturn,
                        onSelected: (val) => setState(() => isDealerReturn = true),
                        selectedColor: Colors.red[100],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  isDealerReturn
                      ? "Stock will Decrease (-1)\nLedger Debt will Decrease."
                      : "Stock will Increase (+1)\nRefund will be issued.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 15),

                // NAME SELECTOR
                Consumer<DbService>(
                    builder: (context, db, _) {
                      return Autocomplete<Party>(
                        optionsBuilder: (textEditingValue) async {
                          if (textEditingValue.text.isEmpty) return const Iterable<Party>.empty();
                          return await db.searchParties(textEditingValue.text);
                        },
                        displayStringForOption: (Party option) => option.name,
                        onSelected: (Party selection) {
                          partyCtrl.text = selection.name;
                          selectedPartyId = selection.id;
                        },
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelText: isDealerReturn ? "Dealer Name" : "Customer Name",
                                border: const OutlineInputBorder(),
                                suffixIcon: const Icon(Icons.person)
                            ),
                            onChanged: (val) {
                              partyCtrl.text = val;
                              selectedPartyId = null;
                            },
                          );
                        },
                      );
                    }
                ),
                const SizedBox(height: 10),

                // SCAN IMEI OR TYPE NAME
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imeiCtrl,
                        decoration: const InputDecoration(labelText: "IMEI (Scan for Mobile)", hintText: "Scan to Auto-fill", border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        onPressed: () async {
                          final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                          if (code != null) {
                            setState(() {
                              imeiCtrl.text = code;
                            });
                          }
                        },
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: productCtrl,
                  decoration: const InputDecoration(labelText: "Product Name (Accessories)", hintText: "e.g. Adapter / Case", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isDealerReturn ? "Cost Price (Reversal)" : "Refund Amount",
                      prefixText: "Rs ",
                      border: const OutlineInputBorder()
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                if ((productCtrl.text.isEmpty && imeiCtrl.text.isEmpty) || amountCtrl.text.isEmpty || partyCtrl.text.isEmpty) {
                  _showErrorPopup("Please fill all details!");
                  return;
                }

                String cleanAmount = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                double val = double.tryParse(cleanAmount) ?? 0;

                final db = Provider.of<DbService>(context, listen: false);

                try {
                  await db.processReturn(
                      productName: productCtrl.text,
                      refundAmount: val,
                      originalCost: 0,
                      customerName: partyCtrl.text,
                      partyId: selectedPartyId,
                      imei: imeiCtrl.text.isNotEmpty ? imeiCtrl.text : null,
                      isDealerReturn: isDealerReturn
                  );

                  if(context.mounted) {
                    Navigator.pop(ctx);
                    _showSuccessPopup("Return Processed Successfully");
                  }
                } catch (e) {
                  _showErrorPopup(e.toString());
                }
              },
              child: const Text("CONFIRM"),
            )
          ],
        ),
      ),
    );
  }

  // --- POPUPS ---
  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.green, size: 50)),
            const SizedBox(height: 20),
            const Text("Success!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: Colors.red, size: 50)),
            const SizedBox(height: 20),
            const Text("Alert", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- CONVERTED TO STATEFUL WIDGET TO FIX CONTEXT/NAVIGATION ISSUES ---
class InventoryGrid extends StatefulWidget {
  final String category;
  final String query;
  const InventoryGrid({super.key, required this.category, required this.query});

  @override
  State<InventoryGrid> createState() => _InventoryGridState();
}

class _InventoryGridState extends State<InventoryGrid> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);
    bool isAdmin = true;
    try { isAdmin = auth.isAdmin; } catch(e) {}

    double width = MediaQuery.of(context).size.width;
    int cols = width > 1100 ? 3 : (width > 700 ? 2 : 1);

    return StreamBuilder<List<Product>>(
      stream: db.searchProducts(widget.query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var rawProducts = snapshot.data!
            .where((p) => p.category == widget.category && p.quantity > 0)
            .toList();

        if (rawProducts.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 10),
            Text("No Stock Available", style: TextStyle(color: Colors.grey[600]))
          ]));
        }

        Map<String, List<Product>> groupedProducts = {};
        for (var p in rawProducts) {
          if (!groupedProducts.containsKey(p.name)) {
            groupedProducts[p.name] = [];
          }
          groupedProducts[p.name]!.add(p);
        }
        var displayList = groupedProducts.entries.toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: 2.0,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16
          ),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final group = displayList[index];
            final mainItem = group.value.first;
            final unitCount = group.value.length;
            final totalQty = group.value.fold(0, (sum, item) => sum + item.quantity);
            bool lowStock = !mainItem.isMobile && totalQty <= 5;

            return Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showGroupSelectionDialog(group.value, isAdmin),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(width: 56, height: 56, decoration: BoxDecoration(color: _getColorForCategory(mainItem.category).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getIconForCategory(mainItem.category), color: _getColorForCategory(mainItem.category), size: 28)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(mainItem.brand.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            const SizedBox(height: 2),
                            Text(mainItem.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),

                            if (mainItem.sourceContact != null && mainItem.sourceContact!.isNotEmpty)
                              Text("Source: ${mainItem.sourceContact}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)
                            else
                              const Text("Source: Walk-In", style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),

                            const SizedBox(height: 6),
                            if (mainItem.isMobile)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                                child: Text("Stock: $unitCount units", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                              )
                            else
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: lowStock ? Colors.red[50] : Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                                  child: Text(lowStock ? "Low Stock: $totalQty" : "Qty: $totalQty", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: lowStock ? Colors.red : Colors.blue[800]))),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Rs ${mainItem.sellPrice.toInt()}", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                          if (isAdmin) Text("Cost: ${mainItem.costPrice.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.red)),
                          const SizedBox(height: 8),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showGroupSelectionDialog(List<Product> group, bool isAdmin) {
    if (group.first.isMobile == false || group.length == 1) {
      _showDetailDialog(group.first, isAdmin);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Select ${group.first.name} Unit"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: group.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final item = group[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.imei ?? 'No IMEI', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Color: ${item.color ?? '-'} | Storage: ${item.memory ?? '-'} \nCond: ${item.condition ?? 'New'}"),
                isThreeLine: true,
                trailing: const Icon(Icons.edit, size: 20, color: Colors.blue),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDetailDialog(item, isAdmin);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  // --- FIXED DETAIL DIALOG ---
  void _showDetailDialog(Product item, bool isAdmin) {
    // Check if widget is still active before showing dialog
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(children: [
          Icon(_getIconForCategory(item.category), color: _getColorForCategory(item.category)),
          const SizedBox(width: 10),
          Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)))
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row("Category", item.category),
              _row("Brand", item.brand),
              const Divider(),
              if (item.isMobile) ...[
                _row("PTA Status", item.ptaStatus ?? "Unknown", isBold: true, color: item.ptaStatus == "Non-PTA" ? Colors.red : Colors.green),
                _row("IMEI", item.imei ?? "N/A", isBold: true),
                _row("Color", item.color ?? "-"),
                _row("Storage", item.memory ?? "-"),
                if(item.batteryHealth != null) _row("Battery Health", item.batteryHealth!),
              ],
              const Divider(),
              if(item.sourceContact != null) _row("Supplier", item.sourceContact!),
              if (isAdmin) _row("Cost Price", "Rs ${item.costPrice.toInt()}", color: Colors.red),
              _row("Sell Price", "Rs ${item.sellPrice.toInt()}", isBold: true, color: const Color(0xFF10B981), size: 18),
            ],
          ),
        ),
        actions: [
          // DELETE BUTTON: Closes this popup first, THEN opens confirm dialog
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // Close Detail Dialog
              // Ensure we are still mounted before showing the next dialog
              if (mounted) _showConfirmDelete(item);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),

          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Close")),

          // EDIT BUTTON: Closes this popup first, THEN navigates
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                Navigator.pop(dialogCtx); // Close Detail Dialog
                // Use main context for navigation, checking mounted
                if (mounted) {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: item)));
                  if (result == true && mounted) {
                    _showSuccessPopup("Product Updated Successfully");
                  }
                }
              },
              child: const Text("Edit Details")
          )
        ],
      ),
    );
  }

  // --- SEPARATE DELETE CONFIRMATION DIALOG ---
  void _showConfirmDelete(Product item) {
    final db = Provider.of<DbService>(context, listen: false);
    String? selectedAccount = "Cash Drawer"; // Default

    showDialog(
      context: context,
      builder: (confirmCtx) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Confirm Delete?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("This will permanently remove the item from stock."),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("⚠️ Financial Impact:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 5),
                        Text("• Rs ${item.costPrice.toInt()} will be REVERSED.", style: const TextStyle(fontSize: 12)),

                        // --- LOGIC TO SHOW ACCOUNT SELECTOR OR DEALER INFO ---
                        FutureBuilder<List<Party>>(
                            future: db.getAllParties(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox.shrink();

                              // Check if source matches a dealer
                              bool isDealer = snapshot.data!.any((p) => p.name == item.sourceContact && p.type == 'DEALER');

                              if (isDealer) {
                                return Text("• Ledger of '${item.sourceContact}' will be adjusted.", style: const TextStyle(fontSize: 12));
                              } else {
                                // IF NOT DEALER, SHOW DROPDOWN
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    const Text("Refund Money To:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    FutureBuilder<List<PaymentAccount>>(
                                        future: db.getPaymentAccounts(),
                                        builder: (context, accSnapshot) {
                                          if (!accSnapshot.hasData) return const SizedBox();

                                          var items = accSnapshot.data!.map((e) => DropdownMenuItem(value: e.name, child: Text(e.name, style: const TextStyle(fontSize: 12)))).toList();

                                          // Ensure selected value is valid
                                          if (selectedAccount != null && !items.any((i) => i.value == selectedAccount)) {
                                            if (items.isNotEmpty) selectedAccount = items.first.value;
                                          }

                                          return DropdownButton<String>(
                                            value: selectedAccount,
                                            isExpanded: true,
                                            isDense: true,
                                            items: items,
                                            onChanged: (val) => setState(() => selectedAccount = val),
                                          );
                                        }
                                    )
                                  ],
                                );
                              }
                            }
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      // Call the DB function with the selected account
                      await db.deleteProduct(item.id, refundAccount: selectedAccount);

                      if (context.mounted) {
                        Navigator.pop(confirmCtx); // Close Alert
                        _showSuccessPopup("Item Deleted & Money Reversed");
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(confirmCtx);
                      _showErrorPopup(e.toString());
                    }
                  },
                  child: const Text("Delete & Reverse"),
                ),
              ],
            );
          }
      ),
    );
  }

  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.green, size: 50)),
            const SizedBox(height: 20),
            const Text("Success!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if(Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: Colors.red, size: 50)),
            const SizedBox(height: 20),
            const Text("Alert", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color, double size = 14}) { return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87, fontSize: size))])); }
  Color _getColorForCategory(String category) { if (category == 'iPhone') return Colors.black; if (category == 'Android') return const Color(0xFF10B981); return Colors.blue; }
  IconData _getIconForCategory(String category) { if (category == 'iPhone') return Icons.phone_iphone; if (category == 'Android') return Icons.phone_android; return Icons.headphones; }
}