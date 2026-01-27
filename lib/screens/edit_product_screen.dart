import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/db_service.dart';
import '../models/schema.dart';
import 'scanner_screen.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final nameCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  final memoryCtrl = TextEditingController();
  final conditionCtrl = TextEditingController();
  final ramCtrl = TextEditingController();
  final batteryHealthCtrl = TextEditingController();
  final imeiCtrl = TextEditingController();

  // State
  late String category;
  String _ptaStatus = 'PTA Approved';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // 1. Identify Category & Brand
    category = widget.product.category ?? "Android";
    if(category == "Mobile" && (widget.product.brand == "APPLE")) category = "iPhone";
    if(category == "Mobile" && (widget.product.brand != "APPLE")) category = "Android";

    // 2. Load Strings
    nameCtrl.text = widget.product.name;
    brandCtrl.text = widget.product.brand;
    costCtrl.text = widget.product.costPrice.toInt().toString();
    sellCtrl.text = widget.product.sellPrice.toInt().toString();
    qtyCtrl.text = widget.product.quantity.toString();

    // 3. Load Specs
    colorCtrl.text = widget.product.color ?? "";
    memoryCtrl.text = widget.product.memory ?? "";
    ramCtrl.text = widget.product.ram ?? "";
    batteryHealthCtrl.text = widget.product.batteryHealth ?? "";
    conditionCtrl.text = widget.product.condition ?? "";
    imeiCtrl.text = widget.product.imei ?? "";
    _ptaStatus = widget.product.ptaStatus ?? "PTA Approved";
  }

  @override
  Widget build(BuildContext context) {
    bool isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("EDIT ${category.toUpperCase()}",
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        // --- DELETE BUTTON REMOVED AS REQUESTED ---
      ),
      body: Form(
        key: _formKey,
        child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  // --- LAYOUTS ---

  Widget _buildMobileLayout() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBasicInfoCard(),
        const SizedBox(height: 16),
        if(category != 'Accessory') ...[
          _buildSpecsCard(),
          const SizedBox(height: 16),
        ],
        _buildFinancialsCard(),
        const SizedBox(height: 24),
        _buildUpdateButton(),
        const SizedBox(height: 40),
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
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildBasicInfoCard(),
                const SizedBox(height: 20),
                if(category != 'Accessory') _buildSpecsCard(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildFinancialsCard(),
                const SizedBox(height: 24),
                _buildUpdateButton(),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- CARDS ---

  Widget _buildBasicInfoCard() {
    return _buildSectionCard(
        title: "Basic Information",
        child: Column(
          children: [
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v!.isEmpty ? "Required" : null,
              decoration: const InputDecoration(labelText: 'MODEL NAME *'),
            ),
            const SizedBox(height: 12),
            if (category != 'iPhone')
              TextFormField(
                controller: brandCtrl,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v!.isEmpty ? "Required" : null,
                decoration: const InputDecoration(labelText: 'BRAND NAME *'),
              ),
          ],
        )
    );
  }

  Widget _buildSpecsCard() {
    bool isAndroid = category == 'Android';
    bool isiPhone = category == 'iPhone';

    return _buildSectionCard(
      title: "Specifications & IMEI",
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _ptaStatus,
            decoration: const InputDecoration(labelText: "PTA STATUS", filled: true),
            items: ["PTA Approved", "Non-PTA", "JV / Sim Locked"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _ptaStatus = v!),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: imeiCtrl,
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\/\-\s]')),
            ],
            decoration: InputDecoration(
              labelText: 'IMEI NUMBER',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () async {
                  // Scan Logic
                  final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                  if (code != null) {
                    setState(() {
                      imeiCtrl.text = code;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: colorCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'COLOR'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: memoryCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'STORAGE (GB)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isAndroid)
                Expanded(
                  child: TextFormField(
                    controller: ramCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'RAM'),
                  ),
                ),
              if (isiPhone)
                Expanded(
                  child: TextFormField(
                    controller: batteryHealthCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'BATTERY HEALTH %'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: conditionCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'CONDITION / FAULTS'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialsCard() {
    return _buildSectionCard(
        title: "Pricing & Stock",
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                    decoration: const InputDecoration(labelText: 'COST (BUY) *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: sellCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                    decoration: const InputDecoration(labelText: 'SELL PRICE *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (category == 'Accessory')
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'TOTAL QUANTITY'),
              ),
          ],
        )
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _updateProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('UPDATE PRODUCT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  void _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final db = Provider.of<DbService>(context, listen: false);

    widget.product.name = nameCtrl.text.toUpperCase();

    // --- AUTO-CLEAN INPUTS ---
    String cleanCost = costCtrl.text.replaceAll(',', '').replaceAll(' ', '');
    String cleanSell = sellCtrl.text.replaceAll(',', '').replaceAll(' ', '');
    String cleanQty = qtyCtrl.text.replaceAll(',', '').replaceAll(' ', '');

    widget.product.costPrice = double.tryParse(cleanCost) ?? widget.product.costPrice;
    widget.product.sellPrice = double.tryParse(cleanSell) ?? widget.product.sellPrice;
    widget.product.quantity = int.tryParse(cleanQty) ?? widget.product.quantity;

    if (category == 'iPhone') {
      widget.product.brand = "APPLE";
      widget.product.batteryHealth = batteryHealthCtrl.text;
      widget.product.ram = "";
    } else if (category == 'Android') {
      widget.product.brand = brandCtrl.text.toUpperCase();
      widget.product.ram = ramCtrl.text.toUpperCase();
      widget.product.batteryHealth = "";
    } else {
      widget.product.brand = brandCtrl.text.toUpperCase();
      widget.product.category = "Accessory";
      widget.product.isMobile = false;
      widget.product.imei = "";
      widget.product.color = "";
      widget.product.memory = "";
    }

    if (category != 'Accessory') {
      widget.product.imei = imeiCtrl.text;
      widget.product.color = colorCtrl.text.toUpperCase();
      widget.product.memory = memoryCtrl.text.toUpperCase();
      widget.product.ptaStatus = _ptaStatus;
      widget.product.condition = conditionCtrl.text.toUpperCase();
    }

    await db.updateProduct(widget.product);

    if(!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product Updated Successfully"), backgroundColor: Colors.green)
    );
  }
}