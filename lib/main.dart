import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/children_manager_screen.dart';
import 'screens/qr_generator_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const PetitPasApp(),
    ),
  );
}

class PetitPasApp extends StatelessWidget {
  const PetitPasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetitPas - Suivi Maternelle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Outfit',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E9F3D),
          primary: const Color(0xFF4E9F3D),
          secondary: const Color(0xFFFF7043),
          surface: const Color(0xFFF8FAF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF2D3748)),
          titleTextStyle: TextStyle(
            color: Color(0xFF2D3748),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const MainNavigationFrame(),
    );
  }
}

class MainNavigationFrame extends StatefulWidget {
  const MainNavigationFrame({super.key});

  @override
  State<MainNavigationFrame> createState() => _MainNavigationFrameState();
}

class _MainNavigationFrameState extends State<MainNavigationFrame> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeDashboardScreen(),
    QrScannerScreen(),
    ChildrenManagerScreen(),
    QrGeneratorScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4E9F3D),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.child_care, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PetitPas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  appProvider.classSettings.name,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF4E9F3D), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFFF7043)),
            onPressed: () {
              setState(() => _currentIndex = 1);
            },
            tooltip: 'Scan Express',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4E9F3D),
        unselectedItemColor: const Color(0xFF718096),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_2),
            activeIcon: Icon(Icons.qr_code_2),
            label: 'Scan & Go',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Élèves',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.print_outlined),
            activeIcon: Icon(Icons.print),
            label: 'Badges QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            activeIcon: Icon(Icons.tune),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
