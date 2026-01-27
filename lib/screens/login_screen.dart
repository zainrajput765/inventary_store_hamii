import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final pinCtrl = TextEditingController();

  bool _isCloudLogin = true;
  String error = "";
  bool _isLoading = false;

  void _login() async {
    setState(() { _isLoading = true; error = ""; });

    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DbService>(context, listen: false);

    // Safety check for Sync Service
    SyncService? sync;
    try { sync = Provider.of<SyncService>(context, listen: false); } catch (e) {}

    bool success = false;

    if (_isCloudLogin) {
      // Option A: Cloud Login
      success = await auth.login(emailCtrl.text.trim(), passwordCtrl.text.trim());
      if (!success) error = "Invalid Email or Password";
    } else {
      // Option B: Local PIN
      String inputPin = pinCtrl.text.trim(); // FIX: Remove spaces

      bool isValid = await db.verifyPin(inputPin);
      bool isAdmin = await db.verifyAdminPin(inputPin);

      if (isValid) {
        // FIX: Log in Anonymously so Sync works!
        await auth.loginAnonymously(isAdmin);
        success = true;
      } else {
        error = "Invalid PIN";
      }
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Trigger Sync immediately
      sync?.forceSync();

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayoutScreen())
      );
    }
  }

  // --- EMERGENCY RESET (Hidden Feature) ---
  // Long press the Logo to reset PIN to 0000 if locked out
  void _emergencyReset() async {
    final db = Provider.of<DbService>(context, listen: false);
    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Emergency Reset"),
          content: const Text("Reset Admin PIN to '0000'?"),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(
                onPressed: ()=>Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("RESET", style: TextStyle(color: Colors.white))
            )
          ],
        )
    );

    if (confirm == true) {
      await db.changeAdminPin("0000");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN Reset to 0000"), backgroundColor: Colors.orange));
        pinCtrl.text = "0000";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onLongPress: _emergencyReset, // HIDDEN RESET
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/logo.jpg', height: 120, width: 120, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.store, size: 80)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("HAMII Mobiles", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 40),
            _buildLoginForm(),
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

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF0F172A), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(onLongPress: _emergencyReset, child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Image.asset('assets/logo.jpg', height: 250, width: 250, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.store, size: 100, color: Colors.white)))),
          const SizedBox(height: 30), const Text("HAMII Mobiles", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)), const Text("Enterprise Resource Planning", style: TextStyle(color: Colors.white70, fontSize: 18))])))),
        Expanded(child: Center(child: SizedBox(width: 450, child: _buildLoginForm()))),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Row(children: [Expanded(child: _buildTab("Cloud Login", true)), Expanded(child: _buildTab("Local PIN", false))]),
            const SizedBox(height: 30),
            if (_isCloudLogin) ...[
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 15),
              TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))),
            ] else ...[
              TextField(controller: pinCtrl, keyboardType: TextInputType.number, obscureText: true, textAlign: TextAlign.center, maxLength: 4, style: const TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "PIN", counterText: ""), onSubmitted: (_) => _login()),
            ],
            if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 15), child: Text(error, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isLoading ? null : _login, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("LOGIN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, bool isCloud) {
    bool isSelected = _isCloudLogin == isCloud;
    return GestureDetector(
      onTap: () => setState(() => _isCloudLogin = isCloud),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF0F172A) : Colors.transparent, width: 3))),
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF0F172A) : Colors.grey)),
      ),
    );
  }
}