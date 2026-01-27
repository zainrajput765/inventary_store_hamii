import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
// import '../services/sync_service.dart'; // Not needed for this screen anymore
import '../models/schema.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    // sync service is no longer needed here as we don't force sync on button click anymore

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("Financials"),
          const SizedBox(height: 10),
          _buildSettingsCard(
              child: ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.teal),
                title: const Text("Manage Payment Accounts"),
                subtitle: const Text("Add Banks / Wallets / Opening Balance"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPaymentAccountsDialog(context, db),
              )
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("Data Management"),
          const SizedBox(height: 10),
          _buildSettingsCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: Colors.blue), // Changed icon to represent cleaning
                    title: const Text("Clear Local Data (Local Reset)"),
                    subtitle: const Text("Wipes local data only. Resyncs when online."),
                    onTap: () => _performLocalReset(context, db), // Updated function call
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text("Complete Factory Reset", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text("DELETE EVERYTHING (Cloud + Local)"),
                    onTap: () => _showFullResetDialog(context, db),
                  ),
                ],
              )
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("Security"),
          const SizedBox(height: 10),
          _buildSettingsCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.password, color: Colors.indigo),
                    title: const Text("Change Admin PIN"),
                    subtitle: const Text("Local Security Code"),
                    onTap: () => _showChangePinDialog(context, db),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_circle, color: Colors.orange),
                    title: const Text("Change Cloud Password"),
                    subtitle: const Text("For Firebase Login"),
                    onTap: () => _showChangeCloudPasswordDialog(context),
                  ),
                ],
              )
          ),
          const SizedBox(height: 30), // Add spacing
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
    );
  }

  // --- DIALOGS ---

  void _showPaymentAccountsDialog(BuildContext context, DbService db) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payment Accounts"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<PaymentAccount>>(
              future: db.getPaymentAccounts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.separated(
                  separatorBuilder: (_,__) => const Divider(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (ctx, i) {
                    final acc = snapshot.data![i];
                    return ListTile(
                      leading: Icon(acc.type == 'BANK' ? Icons.account_balance : (acc.type == 'WALLET' ? Icons.account_balance_wallet : Icons.money), color: Colors.blueGrey),
                      title: Text(acc.name),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteAccount(context, db, acc.id)),
                    );
                  },
                );
              }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () => _showAddAccountDialog(context, db),
              child: const Text("Add New Account")
          )
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, DbService db) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: "0");
    String type = 'BANK';

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                title: const Text("New Account"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name (e.g. Meezan Bank)")),
                    const SizedBox(height: 10),
                    TextField(controller: balanceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Opening Balance (Rs)")),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                        value: type,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: "BANK", child: Text("Bank Account")),
                          DropdownMenuItem(value: "WALLET", child: Text("Digital Wallet")),
                          DropdownMenuItem(value: "CASH", child: Text("Cash Drawer")),
                        ],
                        onChanged: (val) => setState(() => type = val!)
                    )
                  ],
                ),
                actions: [
                  ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isNotEmpty) {
                          // --- AUTO-CLEAN INPUT ---
                          String cleanBal = balanceCtrl.text.replaceAll(',', '').replaceAll(' ', '');
                          double initBal = double.tryParse(cleanBal) ?? 0.0;

                          bool success = await db.addPaymentAccount(
                              nameCtrl.text,
                              type,
                              initialBalance: initBal
                          );
                          Navigator.pop(ctx);
                          if (success) {
                            Navigator.pop(context);
                            _showPaymentAccountsDialog(context, db);
                          } else {
                            // Replaced SnackBar with Error Popup
                            _showErrorDialog(context, "Limit Reached! Max 4 Accounts.");
                          }
                        }
                      },
                      child: const Text("Add")
                  )
                ]
            )
        )
    );
  }

  void _deleteAccount(BuildContext context, DbService db, int id) {
    db.deletePaymentAccount(id);
    Navigator.pop(context);
    _showPaymentAccountsDialog(context, db);
  }

  // --- ACTIONS (Reset & Security) ---

  // UPDATED: Now only wipes local data, NO sync force.
  void _performLocalReset(BuildContext context, DbService db) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.blue)));

    // 1. Wipe Local DB Only
    await db.factoryResetLocal();

    // 2. Do NOT force sync here (it will happen automatically when net is back)

    if(context.mounted) {
      Navigator.pop(context);
      _showSuccessDialog(context, "Local Data Cleared.\nApp is now empty.");
    }
  }

  void _performFullWipe(BuildContext context, DbService db) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.red)));
    try {
      await db.wipeCloudData();
      await db.factoryResetLocal();
      if(context.mounted) Provider.of<AuthService>(context, listen: false).logout();
      if(context.mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch(e) {
      if(context.mounted) {
        Navigator.pop(context);
        _showErrorDialog(context, "Error: $e");
      }
    }
  }

  void _showFullResetDialog(BuildContext context, DbService db) {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("COMPLETE WIPE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("DANGER: This will delete ALL DATA from the Cloud and this Device permanently.\n\nEnter Admin PIN to confirm:", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: "Admin PIN"))
          ]),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
              if(await db.verifyAdminPin(ctrl.text)) { Navigator.pop(ctx); _performFullWipe(context, db); }
            }, child: const Text("DELETE ALL", style: TextStyle(color: Colors.white)))
          ],
        )
    );
  }

  void _showChangeCloudPasswordDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("New Cloud Password"), content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(hintText: "Enter new password")), actions: [ElevatedButton(onPressed: () async {
      if (ctrl.text.length >= 6) {
        try {
          User? user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.updatePassword(ctrl.text);
            Navigator.pop(context);
            _showSuccessDialog(context, "Password Updated Successfully");
          }
        } catch (e) {
          Navigator.pop(context); // Close dialog first if open, or ensure context is valid
          _showErrorDialog(context, "Failed: $e");
        }
      }
    }, child: const Text("Update"))]));
  }

  void _showChangePinDialog(BuildContext context, DbService db) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("New Admin PIN"), content: TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4), actions: [ElevatedButton(onPressed: () {
      if(ctrl.text.length==4) {
        db.changeAdminPin(ctrl.text);
        Navigator.pop(context);
        _showSuccessDialog(context, "Admin PIN Updated");
      }
    }, child: const Text("Update"))]));
  }

  Widget _buildSectionHeader(String title) { return Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)); }
  Widget _buildSettingsCard({required Widget child}) { return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: child); }

  // --- REUSABLE POPUPS ---

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

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Error", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }
}