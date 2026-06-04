import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/photo_state.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/email_screen.dart';

// ─── Warna palette ────────────────────────────────────────────────────────────
const kPrimary       = Color(0xFF5B62B3);
const kBackground    = Color(0xFFEDE2E0);
const kSurface       = Colors.white;
const kBackgroundDark = Color(0xFF121218);
const kSurfaceDark   = Color(0xFF1E1E2E);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final appState = AppState();
  await appState.loadFromStorage();
  runApp(PhotopediaApp(appState: appState));
}

class PhotopediaApp extends StatelessWidget {
  final AppState appState;
  const PhotopediaApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: appState,
      child: ThemeModeScope(
        child: Builder(builder: (ctx) {
          final isDark = ThemeModeScope.of(ctx);
          return MaterialApp(
            title: 'Photopedia',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const MainShell(),
          );
        }),
      ),
    );
  }
}

ThemeData _buildLightTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimary, primary: kPrimary,
    secondary: const Color(0xFF8E93CC),
    surface: kSurface, brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: kBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackground, foregroundColor: kPrimary, elevation: 0,
    titleTextStyle: TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),
  useMaterial3: true,
);

ThemeData _buildDarkTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimary, primary: kPrimary,
    secondary: const Color(0xFF8E93CC),
    surface: kSurfaceDark, brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: kBackgroundDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackgroundDark, foregroundColor: kPrimary, elevation: 0,
    titleTextStyle: TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.bold),
  ),
  cardColor: kSurfaceDark,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),
  useMaterial3: true,
);

// ─── ThemeModeScope ───────────────────────────────────────────────────────────
class ThemeModeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeModeNotifier() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDark);
  }
}

class ThemeModeScope extends InheritedNotifier<ThemeModeNotifier> {
  ThemeModeScope({super.key, required super.child})
      : super(notifier: ThemeModeNotifier());

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()!.notifier!.isDark;

  static void toggle(BuildContext context) =>
      context.findAncestorWidgetOfExactType<ThemeModeScope>()!.notifier!.toggle();

  static ThemeModeNotifier notifierOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()!.notifier!;
}

// ─── Shared Drawer ────────────────────────────────────────────────────────────
/// Drawer seragam dipakai di semua screen.
/// [currentRoute]: nama screen aktif untuk highlight.
/// [scaffoldKey]: opsional — jika null, pakai Scaffold.of(context).
Widget buildAppDrawer(BuildContext context, {String currentRoute = ''}) {
  final isDark = ThemeModeScope.of(context);
  final bg = isDark ? kSurfaceDark : Colors.white;
  final textColor = isDark ? Colors.white70 : Colors.black87;

  void closeAndNavigate(VoidCallback action) {
    Navigator.pop(context); // tutup drawer
    action();
  }

  return Drawer(
    backgroundColor: bg,
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(color: kPrimary),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 28,
                  child: Icon(Icons.person, color: kPrimary, size: 32),
                ),
                const SizedBox(height: 10),
                const Text('Photopedia User',
                    style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text('user@photopedia.com',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12)),
              ],
            ),
          ),

          // ── Email ──
          _DrawerItem(
            icon: Icons.email_rounded,
            label: 'Email',
            selected: currentRoute == 'email',
            textColor: textColor,
            onTap: () => closeAndNavigate(() {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmailScreen()));
            }),
          ),

          // ── Settings ──
          _DrawerItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            selected: currentRoute == 'settings',
            textColor: textColor,
            onTap: () => closeAndNavigate(() {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
          ),

          // ── Analitik ──
          _DrawerItem(
            icon: Icons.bar_chart_rounded,
            label: 'Analitik',
            selected: currentRoute == 'analytics',
            textColor: textColor,
            onTap: () => closeAndNavigate(() {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnalyticsDashboard()));
            }),
          ),

          const Divider(height: 1),

          // ── Dark Mode Toggle ──
          ListTile(
            leading: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: kPrimary),
            title: Text(isDark ? 'Mode Terang' : 'Mode Gelap',
                style: TextStyle(color: textColor)),
            trailing: Switch.adaptive(
              value: isDark,
              onChanged: (_) => ThemeModeScope.toggle(context),
              activeThumbColor: kPrimary,
              activeTrackColor: kPrimary.withValues(alpha: 0.5),
            ),
            onTap: () => ThemeModeScope.toggle(context),
          ),
        ],
      ),
    ),
  );
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color textColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon, required this.label, required this.selected,
    required this.textColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? kPrimary : Colors.grey),
      title: Text(label, style: TextStyle(
        color: selected ? kPrimary : textColor,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: selected,
      selectedTileColor: kPrimary.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }
}

// ─── MainTabNotifier ──────────────────────────────────────────────────────────
class MainTabNotifier extends InheritedWidget {
  final void Function(int) changeTab;
  const MainTabNotifier({super.key, required this.changeTab, required super.child});
  static MainTabNotifier? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabNotifier>();
  @override
  bool updateShouldNotify(MainTabNotifier old) => changeTab != old.changeTab;
}

// ─── MainShell ────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  // Tab indices: 0=Beranda, 1=Kamera, 2=Galeri, 3=Profil(Settings)
  static const List<Widget> _pages = [
    HomeScreen(),
    CameraScreen(),
    GalleryScreen(),
    SettingsScreen(),  // Profil = Settings
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeScope.of(context);
    final navBg = isDark ? kSurfaceDark : Colors.white;

    return MainTabNotifier(
      changeTab: _onItemTapped,
      child: Scaffold(
        key: MainShell.scaffoldKey,
        drawer: buildAppDrawer(context),
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: navBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12, offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(icon: Icons.home_rounded,        label: 'Beranda', selected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
                  _NavItem(icon: Icons.camera_alt_rounded,  label: 'Kamera',  selected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
                  _NavItem(icon: Icons.photo_library_rounded, label: 'Galeri', selected: _selectedIndex == 2, onTap: () => _onItemTapped(2)),
                  _NavItem(icon: Icons.person_rounded,      label: 'Profil',  selected: _selectedIndex == 3, onTap: () => _onItemTapped(3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? kPrimary : Colors.grey.shade400, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 9,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? kPrimary : Colors.grey.shade400,
            )),
          ],
        ),
      ),
    );
  }
}
