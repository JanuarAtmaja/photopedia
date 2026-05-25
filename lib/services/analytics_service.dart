import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model untuk satu entri log aktivitas pengguna.
class ActivityLog {
  final String action; // 'photo_taken', 'photo_clicked', 'photo_sent', 'photo_deleted'
  final DateTime timestamp;
  final String? photoId;

  ActivityLog({
    required this.action,
    required this.timestamp,
    this.photoId,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'photoId': photoId,
      };

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        action: json['action'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        photoId: json['photoId'] as String?,
      );
}

/// Statistik ringkasan aktivitas pengguna.
class UserStats {
  final int totalPhotosTaken;
  final int totalPhotosClicked;
  final int totalPhotosSent;
  final int totalPhotosDeleted;
  final List<ActivityLog> recentLogs;

  const UserStats({
    required this.totalPhotosTaken,
    required this.totalPhotosClicked,
    required this.totalPhotosSent,
    required this.totalPhotosDeleted,
    required this.recentLogs,
  });
}

/// Service untuk mencatat dan membaca statistik aktivitas pengguna.
/// Semua data disimpan di SharedPreferences (persisten lintas sesi).
class AnalyticsService {
  static const _keyLogs = 'analytics_logs';
  static const _keyTaken = 'stat_taken';
  static const _keyClicked = 'stat_clicked';
  static const _keySent = 'stat_sent';
  static const _keyDeleted = 'stat_deleted';

  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _ensureInit() async {
    if (_prefs == null) await init();
  }

  /// Catat bahwa pengguna mengambil foto.
  Future<void> logPhotoTaken({String? photoId}) async {
    await _ensureInit();
    await _increment(_keyTaken);
    await _appendLog(ActivityLog(
      action: 'photo_taken',
      timestamp: DateTime.now(),
      photoId: photoId,
    ));
  }

  /// Catat bahwa pengguna mengklik/membuka foto.
  Future<void> logPhotoClicked({String? photoId}) async {
    await _ensureInit();
    await _increment(_keyClicked);
    await _appendLog(ActivityLog(
      action: 'photo_clicked',
      timestamp: DateTime.now(),
      photoId: photoId,
    ));
  }

  /// Catat bahwa pengguna mengirim foto via email.
  Future<void> logPhotoSent({String? photoId}) async {
    await _ensureInit();
    await _increment(_keySent);
    await _appendLog(ActivityLog(
      action: 'photo_sent',
      timestamp: DateTime.now(),
      photoId: photoId,
    ));
  }

  /// Catat bahwa pengguna menghapus foto.
  Future<void> logPhotoDeleted({String? photoId}) async {
    await _ensureInit();
    await _increment(_keyDeleted);
    await _appendLog(ActivityLog(
      action: 'photo_deleted',
      timestamp: DateTime.now(),
      photoId: photoId,
    ));
  }

  /// Baca semua statistik sekaligus.
  Future<UserStats> getStats() async {
    await _ensureInit();
    final logs = await _readLogs();
    return UserStats(
      totalPhotosTaken: _prefs!.getInt(_keyTaken) ?? 0,
      totalPhotosClicked: _prefs!.getInt(_keyClicked) ?? 0,
      totalPhotosSent: _prefs!.getInt(_keySent) ?? 0,
      totalPhotosDeleted: _prefs!.getInt(_keyDeleted) ?? 0,
      recentLogs: logs.reversed.take(50).toList(),
    );
  }

  /// Reset semua statistik (berguna untuk testing / QA).
  Future<void> resetStats() async {
    await _ensureInit();
    await _prefs!.remove(_keyTaken);
    await _prefs!.remove(_keyClicked);
    await _prefs!.remove(_keySent);
    await _prefs!.remove(_keyDeleted);
    await _prefs!.remove(_keyLogs);
  }

  // ─── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _increment(String key) async {
    final current = _prefs!.getInt(key) ?? 0;
    await _prefs!.setInt(key, current + 1);
  }

  Future<void> _appendLog(ActivityLog log) async {
    final logs = await _readLogs();
    logs.add(log);
    // Simpan maksimum 200 log terakhir agar storage tidak penuh
    final trimmed = logs.length > 200 ? logs.sublist(logs.length - 200) : logs;
    final encoded = jsonEncode(trimmed.map((l) => l.toJson()).toList());
    await _prefs!.setString(_keyLogs, encoded);
  }

  Future<List<ActivityLog>> _readLogs() async {
    final raw = _prefs!.getString(_keyLogs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
