import 'dart:io';
import 'package:flutter/material.dart';

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

  List<PhotoItem> get photos => List.unmodifiable(_photos);
  PhotoItem? get selectedPhoto => _selectedPhoto;

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

  void addPhoto(String path) {
    final photo = PhotoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: path,
      takenAt: DateTime.now(),
    );
    _photos.insert(0, photo);
    _selectedPhoto = photo;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].isFavorite = !_photos[idx].isFavorite;
      notifyListeners();
    }
  }

  void deletePhoto(String id) {
    _photos.removeWhere((p) => p.id == id);
    if (_selectedPhoto?.id == id) _selectedPhoto = null;
    notifyListeners();
  }

  void selectPhoto(PhotoItem photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }

  void updatePhotoAdjustments(
      String id, double brightness, double contrast, double saturation) {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].brightness = brightness;
      _photos[idx].contrast = contrast;
      _photos[idx].saturation = saturation;
      notifyListeners();
    }
  }

  void updatePhotoFilter(String id, String? filter) {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].appliedFilter = filter;
      notifyListeners();
    }
  }

  void updatePhotoPath(String id, String newPath) {
    final idx = _photos.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _photos[idx].path = newPath;
      notifyListeners();
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
