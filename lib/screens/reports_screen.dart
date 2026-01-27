import 'dart:io'; // Required for file creation
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart'; // Required to find storage path
// Removed share_plus import as we are downloading directly now
import '../services/db_service.dart';
import '../models/schema.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Data Variables
  Map<String, double> accountBalances = {};
  double totalStockValue = 0.0;
  double periodSales = 0.0; // This will now represent Cash Revenue
  double periodExpenses = 0.0; // Operating Expenses only
  double periodProfit = 0.0;
  DateTimeRange? _dateRange;

  // State for the Expandable FAB
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Auto-Refresh Listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DbService>(context, listen: false).addListener(_onDbChange);
    });
  }

  @override
  void dispose() {
    Provider.of<DbService>(context, listen: false).removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final db = Provider.of<DbService>(context, listen: false);

    final balances = await db.getCashFlowBalances();
    final stock = await db.getStockValue();

    DateTime start = _dateRange?.start ?? DateTime.now();
    DateTime end = _dateRange?.end ?? DateTime.now();

    // Ensure we cover the full day (00:00:00 to 23:59:59)
    if (_dateRange == null) {
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    } else {
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    }

    final revenue = await db.getRevenueTotal(start, end);
    final expenses = await db.getExpenseTotal(start, end);
    final profit = await db.getNetProfit(start, end);

    if (mounted) {
      setState(() {
        totalStockValue = stock;
        accountBalances = balances;
        periodSales = revenue;
        periodExpenses = expenses;
        periodProfit = profit;
      });
    }
  }

  // --- NEW: DIRECT DOWNLOAD FUNCTION ---
  Future<void> _exportReport() async {
    final db = Provider.of<DbService>(context, listen: false);

    // 1. Get Date Range
    DateTime start = _dateRange?.start ?? DateTime.now();
    DateTime end = _dateRange?.end ?? DateTime.now();

    if (_dateRange == null) {
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    } else {
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    }

    // 2. Fetch Transactions
    List<Transaction> txns = await db.getTransactionsByDate(start, end);

    if (txns.isEmpty) {
      _showErrorPopup(context, "No transactions found for this period.");
      return;
    }

    try {
      // 3. Build CSV String
      StringBuffer csvData = StringBuffer();
      // Add Header
      csvData.writeln("Date,Time,Type,Party Name,Amount,Payment Source,Description");

      // Add Rows
      for (var t in txns) {
        String date = DateFormat('yyyy-MM-dd').format(t.date);
        String time = DateFormat('HH:mm:ss').format(t.date);
        // Clean description to avoid CSV breaking on commas or newlines
        String cleanDesc = (t.description ?? "").replaceAll(',', ' ').replaceAll('\n', ' ');
        String party = t.partyName ?? "-";
        String source = t.paymentSource ?? "-";

        csvData.writeln("$date,$time,${t.type},$party,${t.amount},$source,$cleanDesc");
      }

      // 4. DETERMINE SAVE PATH (Download Logic)
      String filePath;
      String fileName = "Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";

      if (Platform.isAndroid) {
        // Try to save to public "Download" folder
        Directory downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          filePath = "${downloadDir.path}/$fileName";
        } else {
          // Fallback to external storage (Android/data/...)
          final extDir = await getExternalStorageDirectory();
          filePath = "${extDir!.path}/$fileName";
        }
      } else {
        // iOS: Save to Documents (Accessible via Files App)
        final docDir = await getApplicationDocumentsDirectory();
        filePath = "${docDir.path}/$fileName";
      }

      // 5. Write File
      final file = File(filePath);
      await file.writeAsString(csvData.toString());

      // 6. Show Success Message
      _showSuccessPopup(context, "File Downloaded!\n\nSaved to:\n$filePath");

    } catch (e) {
      _showErrorPopup(context, "Download Failed: $e\n\nTry allowing Storage Permissions.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);

    String periodTitle = _dateRange == null
        ? "Today's Performance"
        : "${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Financial Reports", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // --- DOWNLOAD BUTTON ---
          IconButton(
            icon: const Icon(Icons.download, color: Colors.green),
            tooltip: "Save CSV to Device",
            onPressed: _exportReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: _loadData,
            tooltip: "Force Refresh",
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.date_range, color: Colors.blueAccent),
              onPressed: () async {
                final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Colors.blueAccent)), child: child!);
                    }
                );
                setState(() => _dateRange = picked);
                _loadData();
              },
            ),
          )
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen) ...[
            // INVESTMENT BUTTON
            FloatingActionButton.extended(
              heroTag: "capitalBtn",
              onPressed: () {
                _showAddCapitalDialog(context);
                setState(() => _isMenuOpen = false);
              },
              label: const Text("Add Investment"),
              icon: const Icon(Icons.account_balance),
              backgroundColor: Colors.blue[800],
            ),
            const SizedBox(height: 12),

            // INCOME BUTTON
            FloatingActionButton.extended(
              heroTag: "incomeBtn",
              onPressed: () {
                _showAddIncomeDialog(context);
                setState(() => _isMenuOpen = false);
              },
              label: const Text("Add Income"),
              icon: const Icon(Icons.add_circle_outline),
              backgroundColor: Colors.green[600],
            ),
            const SizedBox(height: 12),

            // EXPENSE BUTTON
            FloatingActionButton.extended(
              heroTag: "expBtn",
              onPressed: () {
                _showAddExpenseDialog(context);
                setState(() => _isMenuOpen = false);
              },
              label: const Text("Add Expense"),
              icon: const Icon(Icons.remove_circle_outline),
              backgroundColor: Colors.redAccent,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: "menuBtn",
            onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
            backgroundColor: const Color(0xFFFFFFFF),
            child: Icon(_isMenuOpen ? Icons.close : Icons.add),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: const Text("Current Accounts", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13, letterSpacing: 1)),
            ),

            // Horizontal Account List
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: accountBalances.entries.map((entry) {
                  Color bg = Colors.blue.shade700;
                  if (entry.key.contains("Cash")) bg = Colors.green.shade700;
                  if (entry.key.contains("Wallet")) bg = Colors.purple.shade700;

                  return _buildAccountBox(entry.key, entry.value, bg);
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Performance Cards
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(periodTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if(_dateRange != null)
                        GestureDetector(
                            onTap: (){ setState(() => _dateRange = null); _loadData(); },
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Text("Reset View", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold))
                            )
                        )
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      Expanded(child: _buildMetricTile("Revenue (Cash In)", "Rs ${periodSales.toInt()}", Icons.arrow_downward, Colors.teal)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricTile("Stock Value", "Rs ${totalStockValue.toInt()}", Icons.inventory_2_outlined, Colors.orange)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _buildMetricTile("Operating Exp", "Rs ${periodExpenses.toInt()}", Icons.arrow_upward, Colors.redAccent)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: periodProfit >= 0
                                      ? [Colors.green.shade50, Colors.green.shade100]
                                      : [Colors.red.shade50, Colors.red.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: periodProfit >= 0 ? Colors.green.shade200 : Colors.red.shade200)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Net Profit", style: TextStyle(color: periodProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                  "${periodProfit >= 0 ? '+' : ''} Rs ${periodProfit.toInt()}",
                                  style: TextStyle(color: periodProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900, fontSize: 18, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text("Recent Transactions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Transaction>>(
              future: _dateRange == null
                  ? db.getTransactionsByDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), DateTime.now())
                  : db.getTransactionsByDate(
                  _dateRange!.start,
                  DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59)
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 150,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text("No transactions found", style: TextStyle(color: Colors.grey[400])),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final txn = snapshot.data![index];
                    return _buildTransactionTile(txn, db);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
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

  // --- WIDGETS ---

  Widget _buildAccountBox(String name, double value, Color bgColor) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.white.withOpacity(0.8), size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text("Rs ${value.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))
            ]),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold))
          ]
      ),
    );
  }

  Widget _buildTransactionTile(Transaction txn, DbService db) {
    Color color; IconData icon;
    String sign = "";

    if (txn.type.contains("SALE_CASH") || txn.type == "PAYMENT_IN" || txn.type == "PAYMENT" || txn.type == "STOCK_CORRECTION") {
      color = Colors.green;
      icon = Icons.arrow_downward;
      sign = "+";
    }
    else if (txn.type == "OPENING_BALANCE") {
      color = Colors.blueAccent;
      icon = Icons.savings;
      sign = "+";
    }
    else if (txn.type == "PURCHASE_CREDIT") {
      color = Colors.orange;
      icon = Icons.history;
      sign = "";
    }
    else if (txn.type == "SALE_CREDIT") {
      color = Colors.blue;
      icon = Icons.pending_actions;
      sign = "";
    }
    else if (txn.type == "EXPENSE" || txn.type == "PURCHASE" || txn.type == "PAYMENT_OUT" || txn.type == "REFUND") {
      color = Colors.red;
      icon = Icons.arrow_upward;
      sign = "-";
    }
    else {
      color = Colors.blueGrey;
      icon = Icons.info_outline;
    }

    String displayTitle = txn.description ?? txn.type;
    String? tradeInInfo;

    if (txn.description != null) {
      String firstLine = txn.description!.split("\n")[0];
      if (firstLine.startsWith("Items:")) firstLine = firstLine.replaceAll("Items:", "");
      displayTitle = firstLine.trim();

      if (txn.description!.contains("TRADE-IN:")) {
        var parts = txn.description!.split("TRADE-IN:");
        if (parts.length > 1) tradeInInfo = parts[1].split("(")[0].trim();
      }
    }

    // --- CHECK IF DELETABLE ---
    bool isDeletable = false;
    if (txn.type == 'EXPENSE' || txn.type == 'OPENING_BALANCE') {
      isDeletable = true;
    } else if (txn.type == 'PAYMENT_IN') {
      if (txn.partyId == null) isDeletable = true;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 22, child: Icon(icon, color: color, size: 20)),
        title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (txn.partyName != null && txn.partyName!.isNotEmpty)
                  Expanded(child: Text("${txn.partyName}  •  ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[800]), overflow: TextOverflow.ellipsis)),

                Text("${DateFormat('dd MMM, hh:mm a').format(txn.date)} • ${txn.paymentSource ?? 'Cash'}", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),

            if(tradeInInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 12, color: Colors.orange[800]),
                    const SizedBox(width: 4),
                    Flexible(child: Text("Trade-In: $tradeInInfo", style: TextStyle(fontSize: 11, color: Colors.deepOrange[800], fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$sign ${txn.amount.toInt()}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 8),
            // --- CONDITIONAL DELETE BUTTON ---
            if (isDeletable)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                onPressed: () => _confirmDeleteTransaction(context, db, txn),
              )
            else
              const SizedBox(width: 32),
          ],
        ),
        onTap: () => _showDetailDialog(txn),
      ),
    );
  }

  // --- DELETE TRANSACTION CONFIRMATION ---
  void _confirmDeleteTransaction(BuildContext context, DbService db, Transaction txn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This will reverse the financial effect of this transaction. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await db.deleteTransaction(txn.id);
              Navigator.pop(ctx);
              _showSuccessPopup(context, "Transaction Reversed Successfully");
              _loadData();
            },
            child: const Text("Delete"),
          )
        ],
      ),
    );
  }

  void _showDetailDialog(Transaction txn) {
    String fullDesc = txn.description ?? "";
    String itemsText = fullDesc;
    String? tradeInText;
    String? discountText;

    if (fullDesc.contains("Items:")) {
      if (fullDesc.contains("DISCOUNT:")) {
        var parts = fullDesc.split("DISCOUNT:");
        discountText = parts[1].split("\n")[0].trim();
      }

      if (fullDesc.contains("TRADE-IN:")) {
        var parts = fullDesc.split("TRADE-IN:");
        tradeInText = parts[1].trim();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text("TRANSACTION DETAILS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1))),
                const Divider(thickness: 1, height: 30),

                _detailRow("Date", DateFormat('dd-MM-yyyy hh:mm a').format(txn.date)),
                if (txn.partyName != null) _detailRow("Customer", txn.partyName!),
                _detailRow("Account", txn.paymentSource ?? "Cash"),

                const SizedBox(height: 20),
                const Text("Product Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(itemsText, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
                ),

                if (discountText != null) ...[
                  const SizedBox(height: 10),
                  _detailRow("Discount", discountText, color: Colors.green[700], isBold: true),
                ],

                if (tradeInText != null) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Less Trade-In:", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(child: Text(tradeInText, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  )
                ],

                const Divider(height: 30),
                _detailRow("Net Amount", "Rs ${txn.amount.toInt()}", isBold: true, fontSize: 20, color: Colors.blue[900]),

                const SizedBox(height: 20),
                Center(
                  child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.grey))),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)), Flexible(child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: color ?? Colors.black87), textAlign: TextAlign.right))]));
  }

  // --- NEW DIALOG FOR CAPITAL/INVESTMENT ---
  void _showAddCapitalDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String source = "Cash Drawer";

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Investment / Capital"),
        content: FutureBuilder<List<PaymentAccount>>(
            future: Provider.of<DbService>(context, listen: false).getPaymentAccounts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var accounts = snapshot.data!;
              if (!accounts.any((a) => a.name == source) && accounts.isNotEmpty) {
                source = accounts.first.name;
              }

              return Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Amount", prefixText: "Rs ", filled: true, fillColor: Colors.blue[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: InputDecoration(labelText: "Source (e.g. Owner Funds)", filled: true, fillColor: Colors.blue[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: source,
                    decoration: InputDecoration(labelText: "Deposit To", filled: true, fillColor: Colors.blue[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    items: accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))).toList(),
                    onChanged: (val) => setState(() => source = val!)
                )
              ]);
            }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
              onPressed: () {
                if (amountCtrl.text.isNotEmpty) {
                  // --- AUTO-CLEAN INPUT ---
                  String cleanAmount = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                  Provider.of<DbService>(context, listen: false).addCapital(double.parse(cleanAmount), descCtrl.text, source);
                  Navigator.pop(ctx);
                  // --- SHOW SUCCESS POPUP ---
                  _showSuccessPopup(context, "Investment Added Successfully");
                } else {
                  _showErrorPopup(context, "Please enter an amount");
                }
              },
              child: const Text("Add Investment")
          )
        ])));
  }

  void _showAddIncomeDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String source = "Cash Drawer";

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Income (Revenue)"),
        content: FutureBuilder<List<PaymentAccount>>(
            future: Provider.of<DbService>(context, listen: false).getPaymentAccounts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var accounts = snapshot.data!;
              if (!accounts.any((a) => a.name == source) && accounts.isNotEmpty) {
                source = accounts.first.name;
              }

              return Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Amount", prefixText: "Rs ", filled: true, fillColor: Colors.green[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: InputDecoration(labelText: "Description", filled: true, fillColor: Colors.green[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: source,
                    decoration: InputDecoration(labelText: "Deposit To", filled: true, fillColor: Colors.green[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    items: accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))).toList(),
                    onChanged: (val) => setState(() => source = val!)
                )
              ]);
            }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              onPressed: () {
                if (amountCtrl.text.isNotEmpty) {
                  // --- AUTO-CLEAN INPUT ---
                  String cleanAmount = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                  Provider.of<DbService>(context, listen: false).addIncome(double.parse(cleanAmount), descCtrl.text, source);
                  Navigator.pop(ctx);
                  // --- SHOW SUCCESS POPUP ---
                  _showSuccessPopup(context, "Income Added Successfully");
                } else {
                  _showErrorPopup(context, "Please enter an amount");
                }
              },
              child: const Text("Add Income")
          )
        ])));
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String source = "Cash Drawer";

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Expense"),
        content: FutureBuilder<List<PaymentAccount>>(
            future: Provider.of<DbService>(context, listen: false).getPaymentAccounts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var accounts = snapshot.data!;
              if (!accounts.any((a) => a.name == source) && accounts.isNotEmpty) {
                source = accounts.first.name;
              }

              return Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Amount", prefixText: "Rs ", filled: true, fillColor: Colors.red[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: InputDecoration(labelText: "Description", filled: true, fillColor: Colors.red[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: source,
                    decoration: InputDecoration(labelText: "Paid From", filled: true, fillColor: Colors.red[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    items: accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))).toList(),
                    onChanged: (val) => setState(() => source = val!)
                )
              ]);
            }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () {
            if (amountCtrl.text.isNotEmpty) {
              // --- AUTO-CLEAN INPUT ---
              String cleanAmount = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');
              Provider.of<DbService>(context, listen: false).addExpense(double.parse(cleanAmount), descCtrl.text, source);
              Navigator.pop(ctx);
              // --- SHOW SUCCESS POPUP ---
              _showSuccessPopup(context, "Expense Added Successfully");
            } else {
              // --- SHOW ERROR POPUP ---
              _showErrorPopup(context, "Please enter an amount");
            }
          }, child: const Text("Save Expense"))
        ])));
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 20),
            const Text(
              "Success!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
    // Auto close only if it is NOT the file path popup (which user needs to read)
    if (!message.contains("Saved to:")) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if(Navigator.canPop(context)) Navigator.pop(context);
      });
    }
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 50),
            ),
            const SizedBox(height: 20),
            const Text("Alert", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
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