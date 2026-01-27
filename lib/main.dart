import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/db_service.dart';
import 'services/cart_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/inventory_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/ledgers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/stock_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final dbService = DbService();
  await dbService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dbService),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (context) {
            final db = Provider.of<DbService>(context, listen: false);
            final sync = SyncService(db);
            Future.delayed(const Duration(seconds: 2), () => sync.forceSync());
            sync.startRealtimeSync();

            // --- THE FIX ---
            // Only trigger upload if the change was NOT from the cloud
            db.addListener(() {
              if (sync.status != SyncStatus.syncing && !db.isProcessingCloudData) {
                sync.forceSync();
              }
            });
            // ----------------

            return sync;
          },
        ),
      ],
      child: const MobileMartApp(),
    ),
  );
}

class MobileMartApp extends StatelessWidget {
  const MobileMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAMII Mobiles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A), primary: const Color(0xFF0F172A), secondary: const Color(0xFF10B981), surface: const Color(0xFFF8FAFC), background: const Color(0xFFF1F5F9)),
          scaffoldBackgroundColor: const Color(0xFFF1F5F9),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF0F172A), elevation: 0, centerTitle: true, titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
          inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2)), labelStyle: const TextStyle(color: Colors.grey)),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)))
      ),
      home: const LoginScreen(),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});
  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    bool isWideScreen = MediaQuery.of(context).size.width > 800;

    List<Widget> screens = [
      const StockListScreen(),
      const AddProductScreen(),
      const PosScreen(),
      const LedgersScreen(),
    ];
    if (auth.isAdmin) {
      screens.add(const ReportsScreen());
      screens.add(const SettingsScreen());
    }

    return Scaffold(
      body: Row(
        children: [
          if (isWideScreen)
            NavigationRail(
              extended: true,
              minExtendedWidth: 240,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
              backgroundColor: const Color(0xFF0F172A),
              indicatorColor: const Color(0xFF10B981),
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme: const IconThemeData(color: Colors.white54),
              selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 40, top: 30),
                child: Column(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(50), child: Image.asset('assets/logo.jpg', width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.store, color: Colors.white, size: 50))),
                    const SizedBox(height: 15),
                    const Text("Hamii Mobiles", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                  ],
                ),
              ),
              destinations: _buildDestinations(auth.isAdmin),
              trailing: Expanded(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.only(bottom: 20.0), child: TextButton.icon(onPressed: () { Provider.of<AuthService>(context, listen: false).logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }, icon: const Icon(Icons.logout, color: Colors.redAccent), label: const Text("Logout", style: TextStyle(color: Colors.redAccent)))))),
            ),
          Expanded(child: Scaffold(appBar: !isWideScreen ? AppBar(title: const Text("HAMII Mobiles")) : null, drawer: !isWideScreen ? _buildMobileDrawer(auth.isAdmin) : null, body: screens[_selectedIndex])),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _buildDestinations(bool isAdmin) {
    List<NavigationRailDestination> dests = [
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: Text('Add Stock')),
      const NavigationRailDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: Text('POS')),
      const NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Ledgers')),
    ];
    if (isAdmin) {
      dests.add(const NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Reports')));
      dests.add(const NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')));
    }
    return dests;
  }

  Widget _buildMobileDrawer(bool isAdmin) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                ClipRRect(borderRadius: BorderRadius.circular(40), child: Image.asset('assets/logo.jpg', width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.store, color: Colors.white, size: 40))),
                const SizedBox(height: 10),
                const Text("HAMII Mobiles", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(0, Icons.dashboard, "Dashboard"),
                _drawerItem(1, Icons.add_box, "Add Inventory"),
                _drawerItem(2, Icons.shopping_cart, "Point of Sale"),
                _drawerItem(3, Icons.account_balance_wallet, "Ledgers"),
                if (isAdmin) _drawerItem(4, Icons.analytics, "Reports"),
                if (isAdmin) _drawerItem(5, Icons.settings, "Settings"),
              ],
            ),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: () { Provider.of<AuthService>(context, listen: false).logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    bool isSelected = _selectedIndex == index;
    return ListTile(leading: Icon(icon, color: isSelected ? const Color(0xFF10B981) : Colors.grey), title: Text(title, style: TextStyle(color: isSelected ? const Color(0xFF0F172A) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), selected: isSelected, tileColor: isSelected ? const Color(0xFF10B981).withOpacity(0.1) : null, onTap: () { setState(() => _selectedIndex = index); Navigator.pop(context); });
  }
}