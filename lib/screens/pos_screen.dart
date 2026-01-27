import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../services/db_service.dart';
import '../services/cart_service.dart';
import '../services/sync_service.dart';
import '../models/schema.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'scanner_screen.dart';
import 'dart:math';

// ==============================================================================
// === 1. CONFIGURATION & MODELS
// ==============================================================================

const String shopAddress = "Shop LG-30 Dpoint Plaza Gujranwala";
const String shopPhone = "0300-7444459";

class ReceiptData {
  final List<CartItem> items;
  final double total;
  final double subtotal;
  final double discount;
  final double tradeInAmount;
  final String tradeInModel;
  final String tradeInImei;
  final String paymentMethod;
  final String customerName;
  final DateTime date;
  final double paidAmount;
  final double balanceDue;

  ReceiptData({
    required this.items,
    required this.total,
    required this.subtotal,
    required this.discount,
    required this.tradeInAmount,
    this.tradeInModel = "",
    this.tradeInImei = "",
    required this.paymentMethod,
    required this.customerName,
    required this.date,
    required this.paidAmount,
    required this.balanceDue,
  });
}

class PendingTradeIn {
  String brand;
  String model;
  String imei;
  String color;
  String storage;
  String condition;
  String ptaStatus;
  double value;

  PendingTradeIn({
    required this.brand,
    required this.model,
    required this.imei,
    required this.color,
    required this.storage,
    required this.condition,
    required this.ptaStatus,
    required this.value,
  });
}

PendingTradeIn? globalPendingTradeIn;

// ==============================================================================
// === 2. MAIN POS SCREEN
// ==============================================================================

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String searchQuery = "";
  final TextEditingController searchCtrl = TextEditingController();
  StreamSubscription? _connectivitySubscription;

  // Connectivity State
  bool _isOffline = false;
  bool _isSyncTimeout = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    // 1. Initial Check
    _checkInitialConnectivity();

    // 2. Listen for Connectivity Changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectionState(results);
    });

    // 3. Listen to SyncService (For 30s Timeout)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = Provider.of<SyncService>(context, listen: false);
      syncService.addListener(_onSyncStatusChanged);
      _onSyncStatusChanged(); // Manual check
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _timeoutTimer?.cancel();
    try {
      Provider.of<SyncService>(context, listen: false).removeListener(_onSyncStatusChanged);
    } catch(e) {}
    super.dispose();
  }

  // --- 30s TIMEOUT LOGIC ---
  void _onSyncStatusChanged() {
    if (!mounted) return;
    final status = Provider.of<SyncService>(context, listen: false).status;

    if (status == SyncStatus.syncing) {
      if (_timeoutTimer == null || !_timeoutTimer!.isActive) {
        _timeoutTimer?.cancel();
        _timeoutTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) {
            setState(() => _isSyncTimeout = true);
          }
        });
      }
    } else {
      _timeoutTimer?.cancel();
      if (_isSyncTimeout) {
        setState(() => _isSyncTimeout = false);
      }
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionState(result);
  }

  void _updateConnectionState(List<ConnectivityResult> results) {
    bool isNowOffline = results.contains(ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _isOffline = isNowOffline;
        if (!isNowOffline) _isSyncTimeout = false;
      });
    }

    if (!isNowOffline) {
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
        appBar: AppBar(
          // --- UPDATED COLORFUL TITLE ---
          centerTitle: true,
          title: RichText(
            text: const TextSpan(
              children: [
                TextSpan(text: "Point of ", style: TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                TextSpan(text: "Sale", style: TextStyle(color: Color(0xFF10B981), fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            labelColor: Color(0xFF0F172A),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.phone_android), text: "Android"),
              Tab(icon: Icon(Icons.phone_iphone), text: "iPhone"),
              Tab(icon: Icon(Icons.headphones), text: "Accessories"),
            ],
          ),
          actions: [
            // --- UPDATED SYNC ICON LOGIC ---
            Consumer<SyncService>(
              builder: (context, syncService, child) {
                if (_isOffline || _isSyncTimeout) {
                  return const IconButton(
                      icon: Icon(Icons.wifi_off, color: Colors.grey),
                      onPressed: null,
                      tooltip: "Offline / Slow Connection"
                  );
                }

                switch (syncService.status) {
                  case SyncStatus.syncing:
                    return Container(
                        margin: const EdgeInsets.all(14),
                        width: 20,
                        height: 20,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))
                    );
                  case SyncStatus.success:
                    return IconButton(
                        icon: const Icon(Icons.cloud_done, color: Color(0xFF10B981)),
                        onPressed: () {},
                        tooltip: "Data Synced"
                    );
                  case SyncStatus.error:
                    return IconButton(
                        icon: const Icon(Icons.cloud_off, color: Colors.red),
                        onPressed: () => syncService.forceSync(),
                        tooltip: "Sync Failed"
                    );
                  case SyncStatus.offline:
                    return const IconButton(
                        icon: Icon(Icons.wifi_off, color: Colors.grey),
                        onPressed: null,
                        tooltip: "Offline Mode"
                    );
                  case SyncStatus.idle:
                  default:
                    return IconButton(
                        icon: const Icon(Icons.cloud_queue, color: Colors.grey),
                        onPressed: () => syncService.forceSync()
                    );
                }
              },
            ),
            Consumer<CartService>(
              builder: (context, cart, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: ShakeWidget(
                      shouldShake: cart.items.isNotEmpty,
                      child: Badge(
                        label: Text(cart.items.length.toString()),
                        child: IconButton(
                          icon: const Icon(Icons.shopping_cart),
                          onPressed: () => _showCartSheet(context),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search Name, IMEI, Brand...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                      onPressed: () async {
                        final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                        if (code != null) {
                          searchCtrl.text = code;
                          setState(() => searchQuery = code);
                        }
                      },
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  PosProductGrid(filterType: 'Android', searchQuery: searchQuery),
                  PosProductGrid(filterType: 'iPhone', searchQuery: searchQuery),
                  PosProductGrid(filterType: 'Accessory', searchQuery: searchQuery),
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

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartBottomSheet(),
    );
  }
}

// ==============================================================================
// === 3. PRODUCT GRID (DASHBOARD VIEW)
// ==============================================================================

class PosProductGrid extends StatelessWidget {
  final String filterType;
  final String searchQuery;

  const PosProductGrid({super.key, required this.filterType, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final cart = Provider.of<CartService>(context, listen: false);

    double width = MediaQuery.of(context).size.width;
    int cols = width > 1100 ? 3 : (width > 700 ? 2 : 1);

    return StreamBuilder<List<Product>>(
      stream: db.listenToProducts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var products = snapshot.data!.where((p) => p.category == filterType && p.quantity > 0).toList();

        if (searchQuery.isNotEmpty) {
          String q = searchQuery.toLowerCase();
          products = products.where((p) {
            return p.name.toLowerCase().contains(q) ||
                p.brand.toLowerCase().contains(q) ||
                (p.imei != null && p.imei!.contains(q));
          }).toList();
        }

        if (products.isEmpty) return const Center(child: Text("No Items Found"));

        Map<String, List<Product>> groupedProducts = {};
        for (var p in products) {
          if (!groupedProducts.containsKey(p.name)) {
            groupedProducts[p.name] = [];
          }
          groupedProducts[p.name]!.add(p);
        }

        var displayList = groupedProducts.entries.toList();

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 3.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final group = displayList[index];
            final mainItem = group.value.first;
            final unitCount = group.value.length;
            final totalQty = group.value.fold(0, (sum, item) => sum + item.quantity);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showGroupSelectionDialog(context, cart, group.value),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(filterType == 'iPhone' ? Icons.phone_iphone : filterType == 'Android' ? Icons.phone_android : Icons.headphones, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(mainItem.brand.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            Text(mainItem.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                            if (mainItem.isMobile)
                              Text("Stock: $unitCount units", style: const TextStyle(fontSize: 12, color: Colors.blueGrey))
                            else
                              Text("Qty: $totalQty", style: TextStyle(fontSize: 12, color: totalQty > 0 ? Colors.grey : Colors.red)),
                          ],
                        ),
                      ),
                      Text("Rs ${mainItem.sellPrice.toInt()}", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showGroupSelectionDialog(BuildContext context, CartService cart, List<Product> group) {
    if (group.first.isMobile == false || group.length == 1) {
      _showDetailDialog(context, cart, group.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Select ${group.first.name}"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: group.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final item = group[index];
              return ListTile(
                title: Text("IMEI: ${item.imei ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Color: ${item.color ?? '-'}  |  Cond: ${item.condition ?? '-'}"),
                trailing: Text("Rs ${item.sellPrice.toInt()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDetailDialog(context, cart, item);
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))],
      ),
    );
  }

  void _showDetailDialog(BuildContext context, CartService cart, Product item) {
    int qty = 1;
    TextEditingController qtyCtrl = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Brand: ${item.brand}"),
              if (item.isMobile) ...[
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("IMEI: ${item.imei ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (item.ptaStatus != null) Text("PTA: ${item.ptaStatus}", style: const TextStyle(color: Colors.blue, fontSize: 12)),
                      ],
                    )
                ),
                const SizedBox(height: 8),
                Text("Color: ${item.color ?? '-'} | Storage: ${item.memory ?? '-'}"),
              ],
              const Divider(),
              Text("Price: Rs ${item.sellPrice.toInt()}", style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),

              if (!item.isMobile) ...[
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () { setState(() { qty = (qty > 1) ? qty - 1 : 1; qtyCtrl.text = qty.toString(); }); }),
                    Container(
                      width: 70, margin: const EdgeInsets.symmetric(horizontal: 5),
                      child: TextField(
                        controller: qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                        decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                        onChanged: (val) { int? newVal = int.tryParse(val); if (newVal != null && newVal > 0) { qty = newVal; } },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () { setState(() { qty++; qtyCtrl.text = qty.toString(); }); }),
                  ],
                ),
                Center(child: Text("Total: Rs ${(item.sellPrice * qty).toInt()}", style: const TextStyle(color: Colors.grey, fontSize: 12))),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                bool allAdded = true;
                for(int i = 0; i < qty; i++) {
                  if (!cart.addToCart(item)) allAdded = false;
                }
                Navigator.pop(ctx);

                if (allAdded) {
                  _showSuccessPopup(context, "$qty x ${item.name} Added to Cart");
                } else {
                  // --- SHOW ERROR POPUP ---
                  _showErrorPopup(context, "Some items are Out of Stock!");
                }
              },
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_shopping_cart, size: 18), SizedBox(width: 8), Text("Add to Bill")]),
            )
          ],
        ),
      ),
    );
  }

  // --- REUSABLE POPUPS ---
  void _showSuccessPopup(BuildContext context, String message) {
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
    Future.delayed(const Duration(milliseconds: 1500), () { if(Navigator.canPop(context)) Navigator.pop(context); });
  }

  void _showErrorPopup(BuildContext context, String message) {
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

// ==============================================================================
// === 4. CART & CHECKOUT LOGIC
// ==============================================================================

class CartBottomSheet extends StatefulWidget {
  const CartBottomSheet({super.key});
  @override
  State<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<CartBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (globalPendingTradeIn != null) {
        Provider.of<CartService>(context, listen: false).setTradeIn(globalPendingTradeIn!.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);
    final db = Provider.of<DbService>(context);
    double netTotal = cart.total;
    bool isRefund = netTotal < 0;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(children: [const Icon(Icons.shopping_bag_outlined), const SizedBox(width: 10), const Text("Current Cart", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const Spacer(), IconButton(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.close))]),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: cart.items.length,
              separatorBuilder: (_,__) => const Divider(),
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${item.quantity} x Rs ${item.price.toInt()}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: Icon(Icons.card_giftcard, color: item.isGift ? Colors.green : Colors.grey), onPressed: () => cart.toggleGift(item)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => cart.removeFromCart(item)),
                    ],
                  ),
                );
              },
            ),
          ),
          if (globalPendingTradeIn != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: ListTile(
                leading: const Icon(Icons.swap_horizontal_circle, color: Colors.orange),
                title: Text(globalPendingTradeIn!.model, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                subtitle: Text("Val: Rs ${globalPendingTradeIn!.value.toInt()} (Tap to Edit)"),
                trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { setState(() { globalPendingTradeIn = null; cart.setTradeIn(0); }); }),
                onTap: () => _showTradeInDialog(context),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.3))),
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline, color: Colors.grey),
                title: const Text("Add Trade-In Device", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                onTap: () => _showTradeInDialog(context),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: ListTile(
              leading: const Icon(Icons.discount, color: Colors.green),
              title: const Text("Discount", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              subtitle: const Text("Apply manual discount"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("- Rs ${cart.discount.toInt()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (cart.discount > 0) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => cart.setDiscount(0))
                ],
              ),
              onTap: () => _showDiscountDialog(context, cart),
            ),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("NET PAYABLE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("Rs ${netTotal.abs().toInt()}", style: TextStyle(fontSize: 26, color: isRefund ? Colors.orange : const Color(0xFF10B981), fontWeight: FontWeight.bold))]),
          if (isRefund) const Align(alignment: Alignment.centerRight, child: Text("Shop Pays Customer", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isRefund ? Colors.orange : const Color(0xFF0F172A), padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: cart.items.isEmpty && globalPendingTradeIn == null ? null : () {
                if(cart.items.isEmpty && (globalPendingTradeIn == null || globalPendingTradeIn!.value == 0)) return;
                Navigator.pop(context);
                _showPaymentDialog(context, cart, netTotal, globalPendingTradeIn, db);
              },
              child: Text(isRefund ? "PAY CUSTOMER" : "RECEIVE PAYMENT", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showTradeInDialog(BuildContext context) {
    final modelCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final imeiCtrl = TextEditingController();
    final conditionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final memoryCtrl = TextEditingController();
    String ptaStatus = "PTA Approved";

    if (globalPendingTradeIn != null) {
      modelCtrl.text = globalPendingTradeIn!.model;
      brandCtrl.text = globalPendingTradeIn!.brand;
      imeiCtrl.text = globalPendingTradeIn!.imei;
      conditionCtrl.text = globalPendingTradeIn!.condition;
      amountCtrl.text = globalPendingTradeIn!.value.toString();
      colorCtrl.text = globalPendingTradeIn!.color;
      memoryCtrl.text = globalPendingTradeIn!.storage;
      ptaStatus = globalPendingTradeIn!.ptaStatus;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Customer Trade-In Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter details of the phone you are BUYING:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(controller: brandCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Brand (e.g. APPLE)", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: modelCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Model (e.g. IPHONE X)", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: TextField(controller: imeiCtrl, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-/]'))], decoration: const InputDecoration(labelText: "IMEI Number", border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.qr_code_scanner, size: 30, color: Color(0xFF0F172A)), onPressed: () async { final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())); if (code != null) imeiCtrl.text = code; })]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: ptaStatus, decoration: const InputDecoration(labelText: "PTA Status", border: OutlineInputBorder()), items: const [DropdownMenuItem(value: "PTA Approved", child: Text("PTA Approved")), DropdownMenuItem(value: "Non-PTA", child: Text("Non-PTA")), DropdownMenuItem(value: "JV / Locked", child: Text("JV / Locked"))], onChanged: (val) => setState(() => ptaStatus = val!)),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: TextField(controller: colorCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Color", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: memoryCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Storage", border: OutlineInputBorder())))]),
                const SizedBox(height: 10),
                TextField(controller: conditionCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Condition/Faults", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Agreed Value (Cost)", prefixText: "Rs ", border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                String raw = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                double val = double.tryParse(raw) ?? 0;
                if (modelCtrl.text.isNotEmpty && val > 0 && brandCtrl.text.isNotEmpty) {
                  setState(() {
                    globalPendingTradeIn = PendingTradeIn(brand: brandCtrl.text.toUpperCase(), model: modelCtrl.text.toUpperCase(), imei: imeiCtrl.text, color: colorCtrl.text.toUpperCase(), storage: memoryCtrl.text.toUpperCase(), condition: conditionCtrl.text.toUpperCase(), ptaStatus: ptaStatus, value: val);
                  });
                  Provider.of<CartService>(context, listen: false).setTradeIn(val);
                  Navigator.pop(ctx);
                } else {
                  // --- SHOW ERROR POPUP ---
                  _showErrorPopup(context, "Price & Details Required!");
                }
              },
              child: const Text("Set Trade-In"),
            )
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, CartService cart) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Apply Discount"), content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixText: "Rs ", border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { cart.setDiscount(double.tryParse(ctrl.text) ?? 0); Navigator.pop(ctx); }, child: const Text("Apply"))]));
  }

  void _showPaymentDialog(BuildContext context, CartService cart, double netTotal, PendingTradeIn? tradeInItem, DbService db) {
    bool isRefund = netTotal < 0;
    double amountToSettle = netTotal.abs();
    final customerNameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: amountToSettle.toInt().toString());
    final bankAmountCtrl = TextEditingController(text: "0");
    String? source;
    String? bankSource;
    bool isProcessing = false;
    bool isSplitPayment = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(isRefund ? "Pay Customer" : "Receive Payment", style: TextStyle(color: isRefund ? Colors.orange : const Color(0xFF0F172A))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Bill: Rs ${amountToSettle.toInt()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text("Customer Name:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Autocomplete<Party>(
                    optionsBuilder: (textEditingValue) async {
                      if (textEditingValue.text.isEmpty) return const Iterable<Party>.empty();
                      return await db.searchParties(textEditingValue.text);
                    },
                    displayStringForOption: (Party option) => option.name,
                    onSelected: (Party selection) { customerNameCtrl.text = selection.name; },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                      if (customerNameCtrl.text.isEmpty && textController.text.isNotEmpty) customerNameCtrl.text = textController.text;
                      return TextField(controller: textController, focusNode: focusNode, decoration: const InputDecoration(hintText: "Search or Type Name", border: OutlineInputBorder()), onChanged: (val) => customerNameCtrl.text = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (!isRefund) Row(children: [Checkbox(value: isSplitPayment, onChanged: (val) { setState(() { isSplitPayment = val!; if (isSplitPayment) { amountCtrl.text = "0"; bankAmountCtrl.text = "0"; } else { amountCtrl.text = amountToSettle.toInt().toString(); } }); }), const Text("Split Payment (Cash + Account)")]),
                  const SizedBox(height: 10),
                  FutureBuilder<List<PaymentAccount>>(
                      future: db.getPaymentAccounts(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        var accounts = snapshot.data!;
                        var items = accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))).toList();
                        if (!items.any((i) => i.value == "Cash Drawer")) items.insert(0, const DropdownMenuItem(value: "Cash Drawer", child: Text("Cash Drawer")));
                        if (source == null && items.isNotEmpty) source = items.first.value;
                        if (bankSource == null && accounts.isNotEmpty) bankSource = accounts.first.name;
                        return Column(children: [if (!isSplitPayment) ...[DropdownButtonFormField<String>(value: source, decoration: InputDecoration(labelText: isRefund ? "Paid From" : "Deposit To", border: const OutlineInputBorder()), items: items, onChanged: (val) => setState(() => source = val!)), const SizedBox(height: 10), TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount Paying Now", prefixText: "Rs ", border: OutlineInputBorder()), onChanged: (val) { setState((){}); })] else ...[const Text("1. Cash Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 5), TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cash Amount", prefixText: "Rs ", border: OutlineInputBorder(), isDense: true), onChanged: (val) { setState((){}); }), const SizedBox(height: 10), const Text("2. Bank/Online Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 5), Row(children: [Expanded(flex: 1, child: TextField(controller: bankAmountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Bank Amount", prefixText: "Rs ", border: OutlineInputBorder(), isDense: true), onChanged: (val) { setState((){}); })), const SizedBox(width: 10), Expanded(flex: 2, child: DropdownButtonFormField<String>(value: bankSource, isExpanded: true, decoration: const InputDecoration(labelText: "Select Account", border: OutlineInputBorder(), isDense: true), items: accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))).toList(), onChanged: (val) => setState(() => bankSource = val!)))]) ]]);
                      }
                  ),
                  if (!isRefund) ...[const SizedBox(height: 15), Builder(builder: (ctx) {
                    String cleanAmount = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                    double cash = double.tryParse(cleanAmount) ?? 0;
                    String cleanBank = bankAmountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                    double bank = isSplitPayment ? (double.tryParse(cleanBank) ?? 0) : 0;
                    double totalPaying = cash + bank;
                    double remaining = amountToSettle - totalPaying;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if(isSplitPayment) Text("Total Paying: Rs ${totalPaying.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)), if (remaining > 0) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("Remaining Rs ${remaining.toInt()} will be added to Ledger (Udhaar)", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13))) else if (remaining < 0) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("Change to Return: Rs ${remaining.abs().toInt()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)))]);
                  })]
                ],
              ),
            ),
            actions: [
              if (!isProcessing) TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isRefund ? Colors.orange : const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: isProcessing ? null : () async {
                  setState(() => isProcessing = true);
                  try {
                    String? error = await db.verifyStockAvailability(cart.items);
                    if (error != null) { throw Exception(error); }
                    String cleanCash = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                    String cleanBank = bankAmountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                    double cash = double.tryParse(cleanCash) ?? 0;
                    double bank = isSplitPayment ? (double.tryParse(cleanBank) ?? 0) : 0;
                    double settled = cash + bank;
                    if (!isRefund && settled < amountToSettle && customerNameCtrl.text.isEmpty) { throw Exception("Customer Name required for Udhaar!"); }

                    Product? tradeInProdObj;
                    MobileItem? tradeInMobileObj;
                    if (tradeInItem != null) {
                      tradeInProdObj = Product()..name = tradeInItem.model..brand = tradeInItem.brand..category = (tradeInItem.brand.contains("APPLE") || tradeInItem.brand.contains("IPHONE")) ? "iPhone" : "Android"..isMobile = true..costPrice = tradeInItem.value..sellPrice = tradeInItem.value..quantity = 1..condition = tradeInItem.condition..color = tradeInItem.color..memory = tradeInItem.storage..imei = tradeInItem.imei..ptaStatus = tradeInItem.ptaStatus..sourceContact = "Trade-In: ${customerNameCtrl.text}";
                      tradeInMobileObj = MobileItem()..productName = tradeInItem.model..imei = tradeInItem.imei..status = "IN_STOCK"..specificCostPrice = tradeInItem.value;
                    }
                    String tradeInDesc = tradeInItem != null ? "${tradeInItem.model} (${tradeInItem.imei})" : "";
                    double finalCashPassed = isRefund ? 0 : cash;
                    double finalBankPassed = isRefund ? 0 : bank;

                    await db.processSale(cart.items, cart.subtotal - cart.discount, cart.discount, finalCashPassed, finalBankPassed, bankSource, customerNameCtrl.text, tradeInAmount: cart.tradeInAmount, tradeInDetail: tradeInDesc, tradeInProduct: tradeInProdObj, tradeInItem: tradeInMobileObj);
                    String paymentMethodStr = source ?? "Cash";
                    if (isSplitPayment) paymentMethodStr = "Split (Cash: ${cash.toInt()} | Bank: ${bank.toInt()} via $bankSource)";
                    ReceiptData receiptSnapshot = ReceiptData(items: List.from(cart.items), total: cart.total, subtotal: cart.subtotal, discount: cart.discount, tradeInAmount: cart.tradeInAmount, tradeInModel: tradeInItem != null ? tradeInItem.model : "", tradeInImei: tradeInItem != null ? tradeInItem.imei : "", paymentMethod: paymentMethodStr, customerName: customerNameCtrl.text.toUpperCase(), date: DateTime.now(), paidAmount: settled, balanceDue: (settled < amountToSettle && !isRefund) ? (amountToSettle - settled) : 0);

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _showReceiptPreview(context, receiptSnapshot);
                    cart.clearCart();
                    globalPendingTradeIn = null;
                  } catch (e) {
                    setState(() => isProcessing = false);
                    // --- SHOW ERROR POPUP ---
                    _showErrorPopup(context, e.toString().replaceAll("Exception: ", ""));
                  }
                },
                child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("CONFIRM"),
              )
            ],
          ),
        );
      },
    );
  }

  void _showReceiptPreview(BuildContext context, ReceiptData receipt) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), child: SizedBox(width: 400, height: 600, child: Column(children: [Container(padding: const EdgeInsets.all(12), color: const Color(0xFF0F172A), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Transaction Success", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white))])), Expanded(child: PdfPreview(build: (format) => _generatePdf(receipt), allowPrinting: true, allowSharing: true, initialPageFormat: PdfPageFormat.roll80, pdfFileName: "Receipt-${receipt.date.millisecondsSinceEpoch}.pdf"))]))));
  }

  Future<Uint8List> _generatePdf(ReceiptData receipt) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy, HH:mm:ss').format(receipt.date);
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(10), build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text("HAMII MOBILES", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 10),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Date:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text(date, style: const pw.TextStyle(fontSize: 8))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Customer:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text(receipt.customerName.isEmpty ? "Walk-in" : receipt.customerName, style: const pw.TextStyle(fontSize: 8))]),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text("ITEMS:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.ListView.builder(itemCount: receipt.items.length, itemBuilder: (context, index) {
          final item = receipt.items[index];
          return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(item.product.name + (item.isGift ? "*" : ""), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)), if (item.product.isMobile && item.product.imei != null) pw.Text("IMEI: ${item.product.imei}", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))])), pw.Text("${item.quantity} x ${item.price.toInt()}", style: const pw.TextStyle(fontSize: 9)), pw.SizedBox(width: 8), pw.Text("${(item.price * item.quantity).toInt()}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));
        }),
        if(receipt.tradeInAmount > 0) ...[pw.SizedBox(height: 8), pw.Divider(borderStyle: pw.BorderStyle.dashed), pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text("TRADE-IN:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))), pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(receipt.tradeInModel.isNotEmpty ? receipt.tradeInModel : "Device", style: const pw.TextStyle(fontSize: 9)), if(receipt.tradeInImei.isNotEmpty) pw.Text("IMEI: ${receipt.tradeInImei}", style: const pw.TextStyle(fontSize: 7))]), pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("-${receipt.tradeInAmount.toInt()}", style: const pw.TextStyle(fontSize: 9)))],
        if(receipt.discount > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Discount", style: const pw.TextStyle(fontSize: 9)), pw.Text("-${receipt.discount.toInt()}", style: const pw.TextStyle(fontSize: 9))]),
        pw.SizedBox(height: 8), pw.Divider(borderStyle: pw.BorderStyle.solid),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("NET TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.Text("Rs ${receipt.total.toInt()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))]),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Paid Amount:", style: const pw.TextStyle(fontSize: 10)), pw.Text("Rs ${receipt.paidAmount.toInt()}", style: const pw.TextStyle(fontSize: 10))]),
        if(receipt.balanceDue > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Balance (Udhaar):", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text("Rs ${receipt.balanceDue.toInt()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
        pw.SizedBox(height: 5), pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text("Paid via: ${receipt.paymentMethod}", style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 15), pw.Text("THANK YOU!", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]);
    }));
    return pdf.save();
  }

  // --- REUSABLE ERROR POPUP ---
  void _showErrorPopup(BuildContext context, String message) {
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

// ==============================================================================
// === 5. ANIMATIONS & WIDGETS
// ==============================================================================

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shouldShake;
  final Duration duration;
  final double deltaX;
  final Curve curve;

  const ShakeWidget({super.key, required this.child, required this.shouldShake, this.duration = const Duration(milliseconds: 900), this.deltaX = 4, this.curve = Curves.easeInOut});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.shouldShake) { controller.repeat(reverse: true); }
  }

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldShake && !controller.isAnimating) { controller.repeat(reverse: true); } else if (!widget.shouldShake && controller.isAnimating) { controller.reset(); }
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: (context, child) { final double offset = sin(controller.value * 2 * pi) * widget.deltaX; return Transform.translate(offset: Offset(offset, 0), child: child); }, child: widget.child);
  }
}
