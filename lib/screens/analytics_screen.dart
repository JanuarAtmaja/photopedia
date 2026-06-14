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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    await AnalyticsService.instance.init();
    final stats = await AnalyticsService.instance.getStats();
    if (mounted) setState(() { _stats = stats; _isLoading = false; });
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final isDark = ThemeModeScope.of(context);
    final bg = isDark ? kBackgroundDark : kBackground;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: bg,
      drawer: buildAppDrawer(context, currentRoute: 'analytics'),
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Analitik'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: kPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, color: kPrimary),
            tooltip: 'Ke Beranda',
            onPressed: () => Navigator.of(context)
                .popUntil((route) => route.isFirst),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
            tooltip: 'Reset statistik',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _stats == null
              ? const Center(child: Text('Gagal memuat data.'))
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ringkasan Aktivitas',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _StatCard(
                              label: 'Foto Diambil',
                              value: _stats!.totalPhotosTaken,
                              icon: Icons.camera_alt_rounded,
                              color: kPrimary, isDark: isDark,
                            ),
                            _StatCard(
                              label: 'Foto Diklik',
                              value: _stats!.totalPhotosClicked,
                              icon: Icons.touch_app_rounded,
                              color: const Color(0xFF26A69A), isDark: isDark,
                            ),
                            _StatCard(
                              label: 'Foto Dikirim',
                              value: _stats!.totalPhotosSent,
                              icon: Icons.send_rounded,
                              color: const Color(0xFF66BB6A), isDark: isDark,
                            ),
                            _StatCard(
                              label: 'Foto Dihapus',
                              value: _stats!.totalPhotosDeleted,
                              icon: Icons.delete_rounded,
                              color: const Color(0xFFEF5350), isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Log Aktivitas',
                              style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_stats!.recentLogs.length} entri',
                                style: const TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _stats!.recentLogs.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(36),
                                decoration: BoxDecoration(
                                  color: isDark ? kSurfaceDark : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.history_rounded,
                                        size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 14),
                                    Text('Belum ada aktivitas tercatat.',
                                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Aktivitas akan muncul setelah kamu\nmengambil, mengedit, atau mengirim foto.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.5),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: isDark ? kSurfaceDark : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  children: [
                                    for (int i = 0;
                                        i < _stats!.recentLogs.length;
                                        i++) ...[
                                      _LogTile(log: _stats!.recentLogs[i], isDark: isDark),
                                      if (i < _stats!.recentLogs.length - 1)
                                        Divider(height: 1, indent: 56,
                                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                                    ],
                                  ],
                                ),
                              ),
                        const SizedBox(height: 20),
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
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kSurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  final bool isDark;
  const _LogTile({required this.log, this.isDark = false});

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
      case 'photo_taken': return kPrimary;
      case 'photo_clicked': return const Color(0xFF26A69A);
      case 'photo_sent': return const Color(0xFF66BB6A);
      case 'photo_deleted': return const Color(0xFFEF5350);
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
    final timeStr = DateFormat('dd MMM yyyy, HH:mm:ss')
        .format(log.timestamp.toLocal());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _color().withValues(alpha: 0.10),
        child: Icon(_icon(), color: _color(), size: 18),
      ),
      title: Text(_label(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(timeStr,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      trailing: log.photoId != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${log.photoId!.substring(log.photoId!.length > 6 ? log.photoId!.length - 6 : 0)}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            )
          : null,
    );
  }
}
