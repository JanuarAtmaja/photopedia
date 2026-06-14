import 'package:flutter/material.dart';
import '../main.dart';
import '../models/photo_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifEnabled = true;
  bool _saveOriginal = false;
  String _quality = 'Tinggi';

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeScope.of(context);
    final bgColor = isDark ? kBackgroundDark : kBackground;
    final cardColor = isDark ? kSurfaceDark : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: buildAppDrawer(context, currentRoute: 'settings'),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('Pengaturan'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: kPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: kPrimary),
            tooltip: 'Ke Beranda',
            onPressed: () => Navigator.of(context)
                .popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ── Tampilan ──────────────────────────────────────────────
          _buildSection(
            title: 'Tampilan',
            cardColor: cardColor,
            isDark: isDark,
            children: [
              _buildSwitchTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Mode Gelap',
                subtitle: 'Gunakan tema gelap',
                value: isDark,
                onChanged: (_) => ThemeModeScope.toggle(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Profil ────────────────────────────────────────────────
          _buildSection(
            title: 'Profil',
            cardColor: cardColor,
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.person_outline_rounded,
                title: 'Nama Pengguna',
                subtitle: 'Photopedia User',
                onTap: () => _showEditNameDialog(),
              ),
              _buildTile(
                icon: Icons.email_outlined,
                title: 'Email Pengirim',
                subtitle: 'Diatur di email_service.dart',
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Kamera & Foto ─────────────────────────────────────────
          _buildSection(
            title: 'Kamera & Foto',
            cardColor: cardColor,
            isDark: isDark,
            children: [
              _buildDropdownTile(
                icon: Icons.high_quality_rounded,
                title: 'Kualitas Foto',
                value: _quality,
                items: const ['Rendah', 'Sedang', 'Tinggi'],
                onChanged: (v) => setState(() => _quality = v!),
              ),
              _buildSwitchTile(
                icon: Icons.save_alt_rounded,
                title: 'Simpan Foto Asli',
                subtitle: 'Simpan foto sebelum diedit',
                value: _saveOriginal,
                onChanged: (v) => setState(() => _saveOriginal = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Notifikasi ────────────────────────────────────────────
          _buildSection(
            title: 'Notifikasi',
            cardColor: cardColor,
            isDark: isDark,
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notifikasi',
                subtitle: 'Aktifkan notifikasi aplikasi',
                value: _notifEnabled,
                onChanged: (v) => setState(() => _notifEnabled = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Data ──────────────────────────────────────────────────
          _buildSection(
            title: 'Data',
            cardColor: cardColor,
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.delete_outline_rounded,
                title: 'Hapus Semua Foto',
                subtitle: 'Hapus seluruh foto di galeri',
                iconColor: Colors.red.shade400,
                onTap: () => _confirmClearAll(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tentang ───────────────────────────────────────────────
          _buildSection(
            title: 'Tentang',
            cardColor: cardColor,
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.info_outline_rounded,
                title: 'Versi Aplikasi',
                subtitle: '1.0.0',
                onTap: null,
              ),
              _buildTile(
                icon: Icons.code_rounded,
                title: 'Dibuat dengan',
                subtitle: 'Flutter + Dart',
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    required Color cardColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPrimary.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: children.map((w) {
              final idx = children.indexOf(w);
              final isLast = idx == children.length - 1;
              return Column(
                children: [
                  w,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 52,
                      color: isDark ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.grey.shade100,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? kPrimary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20)
          : null,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: kPrimary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: kPrimary,
        activeTrackColor: kPrimary.withValues(alpha: 0.4),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: kPrimary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w500),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showEditNameDialog() {
    final ctrl = TextEditingController(text: 'Photopedia User');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ubah Nama'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Nama pengguna',
            filled: true,
            fillColor: kPrimary.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Semua Foto?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              AppStateScope.of(context).clearAll();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Semua foto dihapus.'),
                  backgroundColor: kPrimary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
