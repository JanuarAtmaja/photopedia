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
    return Scaffold(
      backgroundColor: const Color(0xFFEDE2E0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE2E0),
        elevation: 0,
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            color: Color(0xFF5B62B3),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF5B62B3)),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profil ────────────────────────────────────────────────
          _buildSection(
            title: 'Profil',
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

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5B62B3),
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
                      color: Colors.grey.shade100,
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
      leading: Icon(icon, color: iconColor ?? const Color(0xFF5B62B3), size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20)
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
      leading: Icon(icon, color: const Color(0xFF5B62B3), size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF5B62B3),
        activeTrackColor: const Color(0xFF5B62B3).withValues(alpha: 0.5),
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
      leading: Icon(icon, color: const Color(0xFF5B62B3), size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 13, color: Color(0xFF5B62B3)),
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
        title: const Text('Ubah Nama'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nama pengguna'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B62B3),
            ),
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
                const SnackBar(
                  content: Text('Semua foto dihapus.'),
                  backgroundColor: Color(0xFF5B62B3),
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
