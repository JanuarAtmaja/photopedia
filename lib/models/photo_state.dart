import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';

class PhotoItem {
  final String id;
  String path;
  final DateTime takenAt;
  bool isFavorite;
  String? appliedFilter;
  double brightness;
  double contrast;
  double saturation;

  PhotoItem({
    required this.id,
    required this.path,
    required this.takenAt,
    this.isFavorite = false,
    this.appliedFilter,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
  });
}

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final List<PhotoItem> _photos = [];
  PhotoItem? _selectedPhoto;
  bool _isLoaded = false;

  List<PhotoItem> get photos => List.unmodifiable(_photos);
  PhotoItem? get selectedPhoto => _selectedPhoto;
  bool get isLoaded => _isLoaded;

  List<PhotoItem> get favoritePhotos =>
      _photos.where((p) => p.isFavorite).toList();

  List<PhotoItem> get todayPhotos {
    final now = DateTime.now();
    return _photos
        .where((p) =>
            p.takenAt.year == now.year &&
            p.takenAt.month == now.month &&
            p.takenAt.day == now.day)
        .toList();
  }

  List<PhotoItem> get thisWeekPhotos {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _photos.where((p) => p.takenAt.isAfter(weekAgo)).toList();
  }

  // ─── Inisialisasi & Persistensi ──────────────────────────────────────────────

  /// Panggil sekali saat app start untuk memuat foto dari storage.
  Future<void> loadFromStorage() async {
    if (_isLoaded) return;
    await StorageService.instance.init();
    await AnalyticsService.instance.init();
    final saved = await StorageService.instance.loadPhotos();
    _photos
      ..clear()
      ..addAll(saved);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.instance.savePhotos(_photos);
  }

  // ─── Operasi Foto ─────────────────────────────────────────────────────────────

  Future<void> addPhoto(String path) async {
    final photo = PhotoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: path,
      takenAt: DateTime.now(),
    );
    _photos.insert(0, photo);
    _selectedPhoto = photo;
    notifyListeners();
    await _persist();
    await AnalyticsService.instance.logPhotoTaken(photoId: photo.id);
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].isFavorite = !_photos[idx].isFavorite;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> deletePhoto(String id) async {
    _photos.removeWhere((p) => p.id == id);
    if (_selectedPhoto?.id == id) _selectedPhoto = null;
    notifyListeners();
    await _persist();
    await AnalyticsService.instance.logPhotoDeleted(photoId: id);
  }

  void selectPhoto(PhotoItem photo) {
    _selectedPhoto = photo;
    notifyListeners();
    AnalyticsService.instance.logPhotoClicked(photoId: photo.id);
  }

  Future<void> updatePhotoAdjustments(
      String id, double brightness, double contrast, double saturation) async {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].brightness = brightness;
      _photos[idx].contrast = contrast;
      _photos[idx].saturation = saturation;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> updatePhotoFilter(String id, String? filter) async {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].appliedFilter = filter;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> clearAll() async {
    _photos.clear();
    _selectedPhoto = null;
    notifyListeners();
    await _persist();
  }

  Future<void> updatePhotoPath(String id, String newPath) async {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].path = newPath;
      notifyListeners();
      await _persist();
    }
  }
}

// Simple InheritedWidget wrapper
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppStateScope>()!
        .notifier!;
  }
}
