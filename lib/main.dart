import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/photo_state.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/email_screen.dart';
import 'screens/analytics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ─── Fase 1: Muat data foto dari SharedPreferences (persistensi) ──────────
  await AppState().loadFromStorage();

  runApp(const PhotopediaApp());
}

class PhotopediaApp extends StatelessWidget {
  const PhotopediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: AppState(),
      child: MaterialApp(
        title: 'Photopedia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B4EFF),
            primary: const Color(0xFF6B4EFF),
            secondary: const Color(0xFFB39DFF),
            surface: const Color(0xFFF8F5FF),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F5FF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF8F5FF),
            foregroundColor: Color(0xFF6B4EFF),
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFF6B4EFF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MainTabNotifier(
      changeTab: _onItemTapped,
      child: Scaffold(
        key: MainShell.scaffoldKey,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF6B4EFF)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: Icon(Icons.person,
                          color: Color(0xFF6B4EFF), size: 35),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Photopedia User',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'user@photopedia.com',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              _buildDrawerTile(0, Icons.home_rounded, 'Beranda'),
              _buildDrawerTile(1, Icons.camera_alt_rounded, 'Camera'),
              _buildDrawerTile(2, Icons.photo_library_rounded, 'Gallery'),
              _buildDrawerTile(3, Icons.email_rounded, 'Email'),
              const Divider(),
              // ─── Analitik ──────────────────────────────────────────────
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded,
                    color: Color(0xFF6B4EFF)),
                title: const Text('Analitik Pengguna'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDashboard()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            HomeScreen(),
            CameraScreen(),
            GalleryScreen(),
            EmailScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Beranda',
                      selected: _selectedIndex == 0,
                      onTap: () => _onItemTapped(0)),
                  _NavItem(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      selected: _selectedIndex == 1,
                      onTap: () => _onItemTapped(1)),
                  _NavItem(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      selected: _selectedIndex == 2,
                      onTap: () => _onItemTapped(2)),
                  _NavItem(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      selected: _selectedIndex == 3,
                      onTap: () => _onItemTapped(3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTile(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF6B4EFF) : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF6B4EFF) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF6B4EFF).withValues(alpha: 0.1),
      onTap: () {
        _onItemTapped(index);
        Navigator.pop(context);
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6B4EFF).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected
                    ? const Color(0xFF6B4EFF)
                    : Colors.grey.shade400,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? const Color(0xFF6B4EFF)
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
