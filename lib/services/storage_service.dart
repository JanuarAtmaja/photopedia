import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo_state.dart';

/// StorageService menangani persistensi data foto ke SharedPreferences.
/// Setiap kali foto ditambah/diedit/dihapus, AppState memanggil service ini
/// agar data tidak hilang saat aplikasi ditutup / browser dimuat ulang.
class StorageService {
  static const _keyPhotos = 'photopedia_photos';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _ensureInit() async {
    if (_prefs == null) await init();
  }

  /// Simpan seluruh daftar foto ke SharedPreferences.
  Future<void> savePhotos(List<PhotoItem> photos) async {
    await _ensureInit();
    final encoded = jsonEncode(
      photos.map((p) => _photoToJson(p)).toList(),
    );
    await _prefs!.setString(_keyPhotos, encoded);
  }

  /// Muat daftar foto dari SharedPreferences.
  /// Mengembalikan list kosong jika belum ada data.
  Future<List<PhotoItem>> loadPhotos() async {
    await _ensureInit();
    final raw = _prefs!.getString(_keyPhotos);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _photoFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Hapus semua data yang tersimpan.
  Future<void> clearAll() async {
    await _ensureInit();
    await _prefs!.remove(_keyPhotos);
  }

  // ─── Serialisasi ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _photoToJson(PhotoItem p) => {
        'id': p.id,
        'path': p.path,
        'takenAt': p.takenAt.toIso8601String(),
        'isFavorite': p.isFavorite,
        'appliedFilter': p.appliedFilter,
        'brightness': p.brightness,
        'contrast': p.contrast,
        'saturation': p.saturation,
      };

  PhotoItem _photoFromJson(Map<String, dynamic> json) => PhotoItem(
        id: json['id'] as String,
        path: json['path'] as String,
        takenAt: DateTime.parse(json['takenAt'] as String),
        isFavorite: json['isFavorite'] as bool? ?? false,
        appliedFilter: json['appliedFilter'] as String?,
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      );
}
