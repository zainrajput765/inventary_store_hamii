import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/db_service.dart';
import '../models/schema.dart';
import 'scanner_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final nameCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final sellCtrl = TextEditingController();

  final colorCtrl = TextEditingController();
  final storageCtrl = TextEditingController();
  final ramCtrl = TextEditingController();
  final batteryHealthCtrl = TextEditingController();
  final conditionCtrl = TextEditingController();
  final imeiInputCtrl = TextEditingController();

  final qtyCtrl = TextEditingController(text: "1");

  List<String> scannedImeis = [];
  String ptaStatus = "PTA Approved";
  String? selectedParty;
  String paymentMode = "Cash";
  String? paymentSource = "Cash Drawer";
  String manualSourceContact = "";
  bool isSaving = false;
  bool autoAddImei = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        brandCtrl.text = "APPLE";
      } else {
        brandCtrl.clear();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 900;
    bool isAccessory = _tabController.index == 2;
    bool isIphone = _tabController.index == 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Add Inventory"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.phone_android), text: "Android"),
            Tab(icon: Icon(Icons.phone_iphone), text: "iPhone"),
            Tab(icon: Icon(Icons.headphones), text: "Accessory"),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isDesktop) ...[
                      _buildStockCounterCard(),
                      const SizedBox(height: 20),
                    ],
                    _buildSectionTitle("Product Details"),
                    const SizedBox(height: 15),
                    _buildBasicDetailsForm(isIphone),
                    const SizedBox(height: 25),

                    if (!isAccessory) ...[
                      _buildSectionTitle(isIphone ? "iPhone Specs" : "Android Specs"),
                      const SizedBox(height: 15),
                      _buildMobileSpecificForm(),
                      const SizedBox(height: 25),
                      _buildBulkImeiSection(),
                    ] else
                      _buildAccessoryForm(),

                    const SizedBox(height: 25),
                    _buildSectionTitle("Pricing & Source"),
                    const SizedBox(height: 15),
                    _buildPricingAndSourceForm(),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        onPressed: isSaving ? null : _saveInventory,
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("SAVE TO INVENTORY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 50),
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
            ),
          ),

          if (isDesktop && !isAccessory)
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStockCounterCard(),
                    const Divider(height: 40),
                    const Text("Recently Scanned", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: scannedImeis.isEmpty
                          ? Center(child: Text("Scan IMEIs to see them here", style: TextStyle(color: Colors.grey[400])))
                          : ListView.separated(
                        itemCount: scannedImeis.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (ctx, i) => ListTile(
                          leading: const Icon(Icons.qr_code, color: Colors.blue),
                          title: Text(scannedImeis[i], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: scannedImeis[i].contains("/") ? const Text("Dual SIM", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                          trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => scannedImeis.removeAt(i))),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 4, height: 24, color: const Color(0xFF10B981), margin: const EdgeInsets.only(right: 10)),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
    ]);
  }

  Widget _buildStockCounterCard() {
    int count = 0;
    if (_tabController.index == 2) {
      count = int.tryParse(qtyCtrl.text) ?? 1; // Accessory default
    } else {
      count = scannedImeis.length; // Mobile starts at 0
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total Units", style: TextStyle(color: Colors.white70, fontSize: 12)), Text("Adding Now", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12)), child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  Widget _buildBasicDetailsForm(bool isIphone) {
    return Column(children: [
      // --- CHANGED: AUTOCOMPLETE TEXT FIELD ---
      Consumer<DbService>(
          builder: (context, db, _) {
            return Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                final products = await db.searchProducts(textEditingValue.text).first;
                return products.map((e) => e.name).toSet().toList();
              },
              onSelected: (String selection) {
                nameCtrl.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Ensure our controller stays in sync
                if(controller.text != nameCtrl.text) controller.text = nameCtrl.text;

                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDeco("Product Name", "e.g. 15 PRO MAX"),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                  onChanged: (val) => nameCtrl.text = val, // Sync changes back
                );
              },
            );
          }
      ),

      const SizedBox(height: 15),
      if (!isIphone)
        TextFormField(controller: brandCtrl, textCapitalization: TextCapitalization.characters, decoration: _inputDeco("Brand", "e.g. SAMSUNG"), validator: (v) => v!.isEmpty ? "Required" : null)
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: const Text("Brand: APPLE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        )
    ]);
  }

  Widget _buildMobileSpecificForm() {
    return Column(
      children: [
        Row(children: [Expanded(child: TextFormField(controller: colorCtrl, decoration: _inputDeco("Color", "e.g. TITANIUM BLUE"))), const SizedBox(width: 15), Expanded(child: TextFormField(controller: storageCtrl, decoration: _inputDeco("Storage", "e.g. 256GB")))]),
        const SizedBox(height: 15),
        Row(children: [Expanded(child: TextFormField(controller: conditionCtrl, decoration: _inputDeco("Condition", "e.g. 10/10"))), const SizedBox(width: 15), Expanded(child: DropdownButtonFormField<String>(value: ptaStatus, decoration: _inputDeco("PTA Status", ""), items: const ["PTA Approved", "Non-PTA", "JV / Locked"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => ptaStatus = v!)))]),
        const SizedBox(height: 15),
        if (_tabController.index == 1) TextFormField(controller: batteryHealthCtrl, keyboardType: TextInputType.number, decoration: _inputDeco("Battery Health %", "e.g. 95")) else TextFormField(controller: ramCtrl, decoration: _inputDeco("RAM", "e.g. 12GB")),
      ],
    );
  }

  Widget _buildBulkImeiSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Add IMEIs (Bulk)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              Row(
                children: [
                  const Text("Auto-Add", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Switch(
                    value: autoAddImei,
                    onChanged: (val) => setState(() => autoAddImei = val),
                    activeColor: Colors.blue,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 5),
          if (!autoAddImei)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text("Dual SIM Mode: Scan 1st, Type '/', Scan 2nd, then click +", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.deepOrange)),
            )
          else
            const Text("For Dual SIM, turn OFF Auto-Add", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: imeiInputCtrl,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/\- ]'))],
                  decoration: _inputDeco("Type IMEI", "e.g. 352... / 353..."),
                  onSubmitted: (val) {
                    if (autoAddImei) {
                      if (val.isNotEmpty && !scannedImeis.contains(val)) {
                        setState(() { scannedImeis.add(val); imeiInputCtrl.clear(); });
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: "Add to List",
                  onPressed: () {
                    final val = imeiInputCtrl.text;
                    if (val.isNotEmpty && !scannedImeis.contains(val)) { setState(() { scannedImeis.add(val); imeiInputCtrl.clear(); }); }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  tooltip: "Scan Barcode",
                  onPressed: () async {
                    final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                    if (code != null) {
                      if (!autoAddImei) {
                        if (imeiInputCtrl.text.isNotEmpty) {
                          imeiInputCtrl.text += " / $code";
                        } else {
                          imeiInputCtrl.text = code;
                        }
                      } else {
                        if (!scannedImeis.contains(code)) { setState(() => scannedImeis.add(code)); }
                      }
                    }
                  },
                ),
              )
            ],
          ),
          if (scannedImeis.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, children: scannedImeis.map((imei) => Chip(label: Text(imei, style: const TextStyle(fontSize: 12)), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () => setState(() => scannedImeis.remove(imei)), backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300))).toList())]
        ],
      ),
    );
  }

  Widget _buildAccessoryForm() { return TextFormField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: _inputDeco("Quantity", "e.g. 50")); }

  Widget _buildPricingAndSourceForm() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(
            controller: costCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDeco("Cost Price (Buying)", "Rs 0"),
            validator: (v) => (v == null || v.isEmpty) ? "Invalid Cost" : null,
          )),
          const SizedBox(width: 15),
          Expanded(child: TextFormField(
            controller: sellCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDeco("Sell Price", "Rs 0"),
            validator: (v) => (v == null || v.isEmpty) ? "Invalid Price" : null,
          ))
        ]),
        const SizedBox(height: 15),
        FutureBuilder<List<Party>>(
          future: Provider.of<DbService>(context, listen: false).getSuppliers(),
          builder: (context, snapshot) {
            var suppliers = snapshot.data ?? [];
            return DropdownButtonFormField<String>(value: selectedParty, decoration: _inputDeco("Purchased From (Dealer)", "Select Supplier"), items: suppliers.map((s) => DropdownMenuItem(value: s.id.toString(), child: Text(s.name))).toList(), onChanged: (val) => setState(() => selectedParty = val));
          },
        ),
        if (selectedParty == null) ...[const SizedBox(height: 15), TextFormField(initialValue: manualSourceContact, decoration: _inputDeco("Or Source Name (Manual)", "If not a registered supplier"), onChanged: (v) => manualSourceContact = v)],
        const SizedBox(height: 15),
        Row(children: [Expanded(child: DropdownButtonFormField<String>(value: paymentMode, decoration: _inputDeco("Payment Mode", ""), items: const ["Cash", "Credit"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => paymentMode = val!))), const SizedBox(width: 15), if (paymentMode == 'Cash') Expanded(child: FutureBuilder<List<PaymentAccount>>(future: Provider.of<DbService>(context, listen: false).getPaymentAccounts(), builder: (context, snapshot) { return DropdownButtonFormField<String>(value: paymentSource, decoration: _inputDeco("Paid From", ""), items: (snapshot.data ?? []).map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(), onChanged: (val) => paymentSource = val); })) else const Spacer()]),
      ],
    );
  }

  InputDecoration _inputDeco(String label, String hint) { return InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)); }

  void _saveInventory() async {
    if (!_formKey.currentState!.validate()) return;

    if (paymentMode == "Credit" && selectedParty == null) {
      _showErrorPopup("For Credit Purchases, you MUST select a registered Supplier.");
      return;
    }
    if (_tabController.index != 2 && scannedImeis.isEmpty) {
      _showErrorPopup("Please add at least one IMEI");
      return;
    }

    setState(() => isSaving = true);
    final db = Provider.of<DbService>(context, listen: false);

    String cleanCost = costCtrl.text.replaceAll(',', '').replaceAll(' ', '');
    String cleanSell = sellCtrl.text.replaceAll(',', '').replaceAll(' ', '');
    String cleanQty = qtyCtrl.text.replaceAll(',', '').replaceAll(' ', '');

    double cost = double.tryParse(cleanCost) ?? 0;
    double sell = double.tryParse(cleanSell) ?? 0;
    int qty = int.tryParse(cleanQty) ?? 1;

    String category = _tabController.index == 0 ? "Android" : (_tabController.index == 1 ? "iPhone" : "Accessory");
    int? partyId = selectedParty != null ? int.parse(selectedParty!) : null;

    String sourceName = "Walk-In";
    if (partyId != null) {
      var suppliers = await db.getSuppliers();
      var dealer = suppliers.firstWhere((s) => s.id == partyId, orElse: () => Party()..name="Dealer");
      sourceName = dealer.name;
    } else if (manualSourceContact.isNotEmpty) {
      sourceName = manualSourceContact;
    }

    List<Product> productsToAdd = [];
    String brand = _tabController.index == 1 ? "APPLE" : brandCtrl.text.toUpperCase();

    if (category == "Accessory") {
      productsToAdd.add(Product()..name = nameCtrl.text.toUpperCase()..brand = brand..category = "Accessory"..quantity = qty..costPrice = cost..sellPrice = sell..isMobile = false..sourceContact = sourceName);
    } else {
      for (String imei in scannedImeis) {
        final p = Product()..name = nameCtrl.text.toUpperCase()..brand = brand..category = category..quantity = 1..costPrice = cost..sellPrice = sell..isMobile = true..sourceContact = sourceName..imei = imei..ptaStatus = ptaStatus..color = colorCtrl.text.toUpperCase()..memory = storageCtrl.text.toUpperCase()..condition = conditionCtrl.text.toUpperCase();
        if (category == "iPhone") { p.batteryHealth = batteryHealthCtrl.text; } else { p.ram = ramCtrl.text.toUpperCase(); }
        productsToAdd.add(p);
      }
    }

    int successCount = 0;

    try {
      for (var p in productsToAdd) {
        double totalTransactionCost = p.costPrice * p.quantity;
        // Updated call to addProduct which handles merging
        bool success = await db.addProduct(p, partyId: partyId, partyName: sourceName, paymentMode: paymentMode, paymentSource: paymentSource, costTotal: totalTransactionCost);
        if (success) successCount++;
      }

      if (mounted) {
        setState(() => isSaving = false);
        _showSuccessPopup(successCount);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        _showErrorPopup(e.toString().replaceAll("Exception:", "").trim());
      }
    }
  }

  void _showSuccessPopup(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 20),
            const Text("Success!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Text("$count items added to inventory successfully.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                onPressed: () { Navigator.pop(ctx); _resetForm(); },
                child: const Text("Add More", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            )
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
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: Colors.red, size: 50)),
            const SizedBox(height: 20),
            const Text("Action Required", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      scannedImeis.clear();
      imeiInputCtrl.clear();
      nameCtrl.clear();
      brandCtrl.clear();
      costCtrl.clear();
      sellCtrl.clear();
      colorCtrl.clear();
      storageCtrl.clear();
      conditionCtrl.clear();
      ramCtrl.clear();
      batteryHealthCtrl.clear();
      qtyCtrl.text = "1";
    });
  }
}