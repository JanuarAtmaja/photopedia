import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/photo_state.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/email_screen.dart';

// ─── Color Palette ───────────────────────────────────────────────────────────
const kPrimary       = Color(0xFF5B62B3);
const kPrimaryLight  = Color(0xFF8E93CC);
const kAccent        = Color(0xFF7C5CFC);
const kBackground    = Color(0xFFF5F2F0);
const kSurface       = Colors.white;
const kBackgroundDark = Color(0xFF0F0F1A);
const kSurfaceDark   = Color(0xFF1A1A2E);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
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
    secondary: kPrimaryLight,
    surface: kSurface, brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: kBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackground, foregroundColor: kPrimary, elevation: 0,
    titleTextStyle: TextStyle(
      color: kPrimary, fontSize: 18, fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      elevation: 0,
    ),
  ),
  useMaterial3: true,
);

ThemeData _buildDarkTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimary, primary: kPrimary,
    secondary: kPrimaryLight,
    surface: kSurfaceDark, brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: kBackgroundDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackgroundDark, foregroundColor: kPrimary, elevation: 0,
    titleTextStyle: TextStyle(
      color: kPrimary, fontSize: 18, fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  ),
  cardColor: kSurfaceDark,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      elevation: 0,
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
    ),
    child: SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [kPrimary, kAccent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text('Photopedia User',
                  style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text('user@photopedia.com',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
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
              ],
            ),
          ),

          // Dark Mode Toggle — bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06)
                             : kPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: kPrimary, size: 22),
                title: Text(isDark ? 'Mode Terang' : 'Mode Gelap',
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                trailing: Switch.adaptive(
                  value: isDark,
                  onChanged: (_) => ThemeModeScope.toggle(context),
                  activeThumbColor: kPrimary,
                  activeTrackColor: kPrimary.withValues(alpha: 0.4),
                ),
                onTap: () => ThemeModeScope.toggle(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: selected ? kPrimary : Colors.grey, size: 22),
        title: Text(label, style: TextStyle(
          color: selected ? kPrimary : textColor,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 14,
        )),
        selected: selected,
        selectedTileColor: kPrimary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
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

// ─── MainShell (Lazy-loaded pages for performance) ────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // Lazy-loaded pages — only built when first accessed
  final Map<int, Widget> _cachedPages = {};

  Widget _getPage(int index) {
    return _cachedPages.putIfAbsent(index, () {
      switch (index) {
        case 0: return const HomeScreen();
        case 1: return const CameraScreen();
        case 2: return const GalleryScreen();
        case 3: return const SettingsScreen();
        default: return const HomeScreen();
      }
    });
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeScope.of(context);
    final navBg = isDark
        ? kSurfaceDark.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);

    return MainTabNotifier(
      changeTab: _onItemTapped,
      child: Scaffold(
        key: MainShell.scaffoldKey,
        drawer: buildAppDrawer(context),
        body: _getPage(_selectedIndex),
        extendBody: true,
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 24, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? kPrimary : Colors.grey.shade400, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? kPrimary : Colors.grey.shade400,
            )),
          ],
        ),
      ),
    );
  }
}
