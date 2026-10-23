import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/settings_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  final SettingsRepository _settingsRepo = SettingsRepository.instance;
  final GoogleDriveService _drive = GoogleDriveService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _customClientId;
  String? get customClientId => _customClientId;

  GoogleSignInAccount? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.isAuthenticated;
  String? get userEmail => _auth.userEmail;
  String? get userDisplayName => _auth.userDisplayName;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _customClientId = await _settingsRepo.getCustomOAuthClientId();
      await _auth.restoreSession(clientId: _customClientId);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signIn(clientId: _customClientId);
      _drive.clearFolderCache();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _auth.signOut();
    _drive.clearFolderCache();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _isLoading = true;
    notifyListeners();

    await _auth.disconnect();
    _drive.clearFolderCache();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCustomClientId(String? clientId) async {
    _customClientId = clientId;
    await _settingsRepo.saveCustomOAuthClientId(clientId);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
