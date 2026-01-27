import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/db_service.dart';
import '../models/schema.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'ledger_pdf_generator.dart';

class LedgersScreen extends StatelessWidget {
  const LedgersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: RichText(
            text: const TextSpan(
              children: [
                TextSpan(text: "Ledgers ", style: TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                TextSpan(text: "& Khata", style: TextStyle(color: Color(0xFF10B981), fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            labelColor: Color(0xFF0F172A),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Payable (Suppliers)"),
              Tab(text: "Receivable (Customers)"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text("Add Party"),
          backgroundColor: const Color(0xFFFFFFFF),
          onPressed: () => _showAddPartyDialog(context),
        ),
        // REPLACE THE EXISTING BODY WITH THIS:
        body: Column(
          children: [
            const Expanded(
              child: TabBarView(
                children: [
                  PartyList(type: "DEALER"),
                  PartyList(type: "CUSTOMER"),
                ],
              ),
            ),

            // PASTE FOOTER HERE 👇
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

  // --- ADD PARTY DIALOG ---
  void _showAddPartyDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: "0");

    String type = "DEALER";
    bool isStandardDebt = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Add New Contact", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: "Name", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Phone", prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder())
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: "Type", prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "DEALER", child: Text("Dealer (Supplier)")),
                    DropdownMenuItem(value: "CUSTOMER", child: Text("Customer (Shop Owner)")),
                  ],
                  onChanged: (val) => setState(() {
                    type = val!;
                    isStandardDebt = true;
                  }),
                ),

                const SizedBox(height: 15),
                const Divider(),
                const Text("Initial Balance (Optional)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),

                TextField(
                  controller: balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Opening Amount (Rs)", prefixIcon: Icon(Icons.money), border: OutlineInputBorder()),
                ),

                const SizedBox(height: 10),

                Column(
                  children: [
                    RadioListTile<bool>(
                      title: Text(
                          type == "DEALER" ? "I Owe Him (Payable)" : "He Owes Me (Receivable)",
                          style: TextStyle(color: type == "DEALER" ? Colors.red : Colors.green, fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                      value: true,
                      groupValue: isStandardDebt,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: type == "DEALER" ? Colors.red : Colors.green,
                      onChanged: (val) => setState(() => isStandardDebt = val!),
                    ),
                    RadioListTile<bool>(
                      title: Text(
                          type == "DEALER" ? "He Owes Me (Advance)" : "I Owe Him (Advance/Liability)",
                          style: TextStyle(color: type == "DEALER" ? Colors.green : Colors.red, fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                      value: false,
                      groupValue: isStandardDebt,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: type == "DEALER" ? Colors.green : Colors.red,
                      onChanged: (val) => setState(() => isStandardDebt = val!),
                    ),
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  Provider.of<DbService>(context, listen: false).addParty(nameCtrl.text, phoneCtrl.text, type).then((_) async {
                    // --- AUTO-CLEAN INPUT ---
                    String cleanBal = balanceCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                    double openingBal = double.tryParse(cleanBal) ?? 0.0;

                    if (openingBal > 0) {
                      final db = Provider.of<DbService>(context, listen: false);
                      final parties = await db.getAllParties();
                      try {
                        final newParty = parties.firstWhere((p) => p.name == nameCtrl.text && p.type == type);
                        db.updatePartyBalance(newParty.id, openingBal, isStandardDebt, "Opening Balance");
                      } catch (e) {
                        // Party might take a split second to save, handle gracefully
                      }
                    }
                  });
                  Navigator.pop(ctx);
                  // --- BEAUTIFUL SUCCESS POPUP ---
                  _showSuccessDialog(context, "Contact Added Successfully");
                }
              },
              child: const Text("Save Contact"),
            )
          ],
        ),
      ),
    );
  }

  // --- REUSABLE SUCCESS POPUP (For LedgersScreen) ---
  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
            ),
            const SizedBox(height: 15),
            const Text("Success!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class PartyList extends StatelessWidget {
  final String type;
  const PartyList({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    bool isDealer = type == 'DEALER';

    double width = MediaQuery.of(context).size.width;
    int cols = width > 1100 ? 3 : (width > 700 ? 2 : 1);

    return StreamBuilder<List<Party>>(
      stream: db.listenToParties(type),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        List<Party> displayList = snapshot.data!;

        if (!isDealer) {
          displayList = displayList.where((p) => p.balance != 0).toList();
        }

        if (displayList.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 60, color: Colors.green[200]),
            const SizedBox(height: 10),
            Text(isDealer ? "No Supplier Records" : "No Active Customer Udhaar", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
            Text(isDealer ? "Add suppliers to manage purchases" : "Zero balance customers are hidden", style: TextStyle(color: Colors.grey[400], fontSize: 12))
          ]));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final party = displayList[index];

            bool isPositive = party.balance > 0;
            Color balanceColor;
            String statusText;

            if (party.balance == 0) {
              balanceColor = Colors.grey;
              statusText = "Settled";
            } else if (isDealer) {
              balanceColor = isPositive ? Colors.red : Colors.green;
              statusText = isPositive ? "Payable" : "Advance Paid";
            } else {
              balanceColor = isPositive ? Colors.green : Colors.red;
              statusText = isPositive ? "Receivable" : "Advance Received";
            }

            return Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showTransactionDashboard(context, db, party),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: balanceColor.withOpacity(0.1),
                        child: Text(party.name.isNotEmpty ? party.name[0].toUpperCase() : "?", style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(party.phone.isEmpty ? "No Phone" : party.phone, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Rs ${party.balance.abs().toInt()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: balanceColor)),
                          Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: balanceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(statusText, style: TextStyle(fontSize: 10, color: balanceColor, fontWeight: FontWeight.bold))
                          ),
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

  void _showTransactionDashboard(BuildContext context, DbService db, Party party) {
    bool isDealer = party.type == "DEALER";
    Color themeColor = isDealer ? Colors.orange : Colors.teal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: themeColor.withOpacity(0.1), child: Icon(Icons.person, color: themeColor)),
                const SizedBox(width: 12),
                Expanded(child: Text(party.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                    onPressed: () async {
                      List<Transaction> history = await db.getPartyHistory(party.id);
                      final pdfData = await generateLedgerPdf(party, history);
                      await Printing.layoutPdf(onLayout: (format) => pdfData);
                    }
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(context, db, party)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),

            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor.withOpacity(0.3))
              ),
              child: Column(
                children: [
                  Text("Current Balance", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  const SizedBox(height: 5),
                  Text("Rs ${party.balance.toInt()}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: themeColor)),
                  Text(
                      party.balance == 0 ? "Fully Settled" : (party.balance > 0 ? (isDealer ? "You need to PAY this" : "Receivable Amount") : (isDealer ? "Advance Paid" : "Advance Received")),
                      style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: isDealer ? Colors.redAccent : Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _showAddTransactionDialog(context, db, party, true),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isDealer ? Icons.shopping_bag : Icons.sell, size: 18), const SizedBox(width: 8), Text(isDealer ? "Purchase (Credit)" : "Sale (Credit)")]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _showAddTransactionDialog(context, db, party, false),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.attach_money, size: 18), const SizedBox(width: 8), Text(isDealer ? "Pay Supplier" : "Receive Payment")]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),

            Expanded(child: _buildHistoryList(context, db, party)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, DbService db, Party party) {
    return FutureBuilder<List<Transaction>>(
      future: db.getPartyHistory(party.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("No transactions yet", style: TextStyle(color: Colors.grey[400])));

        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final txn = snapshot.data![index];
            bool isIncrease = txn.type.contains("CREDIT") || txn.type == "PURCHASE_CREDIT" || txn.type == "CREDIT_ADDED";

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isIncrease ? Colors.red[50] : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: Icon(isIncrease ? Icons.arrow_upward : Icons.arrow_downward, color: isIncrease ? Colors.red : Colors.green, size: 20),
              ),
              title: Text(txn.description ?? txn.type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(DateFormat('MMM dd, hh:mm a').format(txn.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${isIncrease ? '+' : '-'} Rs ${txn.amount.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isIncrease ? Colors.red : Colors.green)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                    onPressed: () => _confirmReverseTxn(context, db, txn),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog(BuildContext context, DbService db, Party party, bool isCredit) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? source;
    bool isDealer = party.type == "DEALER";

    String title = "";
    if (isCredit) {
      title = isDealer ? "Record Purchase (Increase Debt)" : "Record Sale (Increase Receivable)";
    } else {
      title = isDealer ? "Pay Supplier (Reduce Debt)" : "Receive from Customer (Reduce Receivable)";
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixText: "Rs ", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: "Note (Optional)", border: OutlineInputBorder())),

              if (!isCredit) ...[
                const SizedBox(height: 10),
                FutureBuilder<List<PaymentAccount>>(
                    future: db.getPaymentAccounts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      if(source == null && snapshot.data!.isNotEmpty) source = snapshot.data!.first.name;

                      return DropdownButtonFormField<String>(
                        value: source,
                        decoration: const InputDecoration(labelText: "Paid From / To", border: OutlineInputBorder()),
                        items: snapshot.data!.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))).toList(),
                        onChanged: (val) => setState(() => source = val!),
                      );
                    }
                )
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (amountCtrl.text.isNotEmpty) {
                  String note = noteCtrl.text.isEmpty ? title : noteCtrl.text;
                  if(!isCredit && source != null) note += " ($source)";

                  // --- AUTO-CLEAN INPUT ---
                  String cleanAmount = amountCtrl.text.replaceAll(',', '').replaceAll(' ', '');

                  db.updatePartyBalance(party.id, double.parse(cleanAmount), isCredit, note);
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  // --- BEAUTIFUL SUCCESS POPUP ---
                  _showSuccessDialog(context, "Transaction Saved");
                }
              },
              child: const Text("Save Transaction"),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DbService db, Party party) {
    // --- UPDATED: ZERO BALANCE CHECK ---
    if (party.balance.abs() > 0) {
      _showErrorDialog(context, "Cannot delete contact.\nBalance is not Zero.\n\nPlease settle the account first.");
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Party?"),
        content: const Text("This will delete all transaction history for this contact."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () {
            db.deleteParty(party.id);
            Navigator.pop(ctx);
            Navigator.pop(context);
            // --- ADDED SUCCESS POPUP FOR DELETION ---
            _showSuccessDialog(context, "Contact Deleted Successfully");
          }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _confirmReverseTxn(BuildContext context, DbService db, Transaction txn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reverse Transaction?"),
        content: const Text("This will undo the balance change. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            db.deleteTransaction(txn.id);
            Navigator.pop(ctx);
            Navigator.pop(context);
            // --- ADDED SUCCESS POPUP FOR REVERSAL ---
            _showSuccessDialog(context, "Transaction Reversed");
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Reverse"))
        ],
      ),
    );
  }

  // --- ADDED: _showSuccessDialog to PartyList Class to fix scope error ---
  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
            ),
            const SizedBox(height: 15),
            const Text("Success!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- ADDED: _showErrorDialog for Validation ---
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 50),
            ),
            const SizedBox(height: 15),
            const Text("Alert", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            )
          ],
        ),
      ),
    );
  }
}