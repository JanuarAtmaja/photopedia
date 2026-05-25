import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../main.dart';

/// AnalyticsDashboard menampilkan statistik aktivitas pengguna:
/// jumlah klik foto, foto diambil, foto dikirim, foto dihapus,
/// beserta log aktivitas 50 terakhir.
class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  UserStats? _stats;
  bool _isLoading = true;

  static const _primary = Color(0xFF6B4EFF);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await AnalyticsService.instance.getStats();
    if (mounted) setState(() { _stats = stats; _isLoading = false; });
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Statistik?'),
        content: const Text('Semua data aktivitas akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AnalyticsService.instance.resetStats();
      await _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text('Analitik Pengguna'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Reset statistik',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('Gagal memuat data.'))
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Kartu statistik ─────────────────────────────
                        const Text(
                          'Ringkasan Aktivitas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          children: [
                            _StatCard(
                              label: 'Foto Diambil',
                              value: _stats!.totalPhotosTaken,
                              icon: Icons.camera_alt_rounded,
                              color: _primary,
                            ),
                            _StatCard(
                              label: 'Foto Diklik',
                              value: _stats!.totalPhotosClicked,
                              icon: Icons.touch_app_rounded,
                              color: Colors.teal,
                            ),
                            _StatCard(
                              label: 'Foto Dikirim',
                              value: _stats!.totalPhotosSent,
                              icon: Icons.send_rounded,
                              color: Colors.green,
                            ),
                            _StatCard(
                              label: 'Foto Dihapus',
                              value: _stats!.totalPhotosDeleted,
                              icon: Icons.delete_rounded,
                              color: Colors.red,
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ─── Log aktivitas ───────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Log Aktivitas Terbaru',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_stats!.recentLogs.length} entri',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_stats!.recentLogs.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Belum ada aktivitas tercatat.',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _stats!.recentLogs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final log = _stats!.recentLogs[index];
                              return _LogTile(log: log);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ─── Widgets pendukung ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  const _LogTile({required this.log});

  IconData _icon() {
    switch (log.action) {
      case 'photo_taken': return Icons.camera_alt_rounded;
      case 'photo_clicked': return Icons.touch_app_rounded;
      case 'photo_sent': return Icons.send_rounded;
      case 'photo_deleted': return Icons.delete_rounded;
      default: return Icons.info_outline;
    }
  }

  Color _color() {
    switch (log.action) {
      case 'photo_taken': return const Color(0xFF6B4EFF);
      case 'photo_clicked': return Colors.teal;
      case 'photo_sent': return Colors.green;
      case 'photo_deleted': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _label() {
    switch (log.action) {
      case 'photo_taken': return 'Foto diambil';
      case 'photo_clicked': return 'Foto diklik';
      case 'photo_sent': return 'Foto dikirim via email';
      case 'photo_deleted': return 'Foto dihapus';
      default: return log.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID')
        .format(log.timestamp.toLocal());
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: _color().withValues(alpha: 0.12),
        child: Icon(_icon(), color: _color(), size: 16),
      ),
      title: Text(_label(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(timeStr,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: log.photoId != null
          ? Text(
              '#${log.photoId!.substring(log.photoId!.length > 6 ? log.photoId!.length - 6 : 0)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            )
          : null,
    );
  }
}
