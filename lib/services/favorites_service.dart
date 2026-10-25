import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages locally favorited media items with instant in-memory lookup
/// and SharedPreferences persistence.
class FavoritesService extends ChangeNotifier {
  static final FavoritesService instance = FavoritesService._internal();
  FavoritesService._internal();

  static const String _prefsKey = 'user_favorite_media_ids';
  final Set<String> _favoriteIds = {};
  bool _initialized = false;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  int get count => _favoriteIds.length;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      _favoriteIds.addAll(list);
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FavoritesService init error: $e');
      _initialized = true;
    }
  }

  bool isFavorite(String localId) {
    return _favoriteIds.contains(localId);
  }

  Future<bool> toggleFavorite(String localId) async {
    if (_favoriteIds.contains(localId)) {
      _favoriteIds.remove(localId);
    } else {
      _favoriteIds.add(localId);
    }
    notifyListeners();
    _saveToPrefs();
    return _favoriteIds.contains(localId);
  }

  Future<void> setFavorite(String localId, bool favorite) async {
    final changed = favorite ? _favoriteIds.add(localId) : _favoriteIds.remove(localId);
    if (changed) {
      notifyListeners();
      _saveToPrefs();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _favoriteIds.toList());
    } catch (e) {
      debugPrint('Failed to save favorites: $e');
    }
  }
}
