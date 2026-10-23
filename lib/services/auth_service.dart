import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';

/// Custom HTTP Client that attaches Google Sign-In authorization headers to every request
class AuthenticatedHttpClient extends http.BaseClient {
  final Future<Map<String, String>> Function() _headerProvider;
  final http.Client _inner = http.Client();

  AuthenticatedHttpClient(this._headerProvider);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _headerProvider();
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class AuthService {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserDisplayName = 'auth_user_display_name';

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userDisplayName => _currentUser?.displayName;

  /// Initializes GoogleSignIn with the narrowest suitable Drive scope
  void _initGoogleSignIn({String? clientId}) {
    _googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'profile',
        AppConstants.driveFileScope,
      ],
      clientId: clientId,
    );
  }

  GoogleSignIn get _signInInstance {
    _googleSignIn ??= GoogleSignIn(
      scopes: [
        'email',
        'profile',
        AppConstants.driveFileScope,
      ],
    );
    return _googleSignIn!;
  }

  /// Restores signed-in account silently on app launch
  Future<GoogleSignInAccount?> restoreSession({String? clientId}) async {
    try {
      if (clientId != null && clientId.isNotEmpty) {
        _initGoogleSignIn(clientId: clientId);
      }
      final account = await _signInInstance.signInSilently();
      _currentUser = account;
      if (account != null) {
        await _saveUserMetadata(account);
      }
      return account;
    } catch (e) {
      // Non-fatal, silent sign-in failure means user needs to sign in explicitly
      return null;
    }
  }

  /// Triggers interactive Google OAuth 2.0 sign-in
  Future<GoogleSignInAccount> signIn({String? clientId}) async {
    try {
      if (clientId != null && clientId.isNotEmpty) {
        _initGoogleSignIn(clientId: clientId);
      }
      final account = await _signInInstance.signIn();
      if (account == null) {
        throw AuthException('Sign-in cancelled by user');
      }

      _currentUser = account;
      await _saveUserMetadata(account);
      return account;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        'Google Authentication failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Disconnects and signs out current Google account
  Future<void> signOut() async {
    try {
      await _signInInstance.signOut();
    } catch (_) {}
    _currentUser = null;
    await _clearUserMetadata();
  }

  /// Completely revokes access permissions
  Future<void> disconnect() async {
    try {
      await _signInInstance.disconnect();
    } catch (_) {}
    _currentUser = null;
    await _clearUserMetadata();
  }

  /// Returns an authenticated HTTP Client suitable for Google Drive API calls
  Future<http.Client> getAuthenticatedClient() async {
    if (_currentUser == null) {
      // Attempt silent sign-in
      final account = await restoreSession();
      if (account == null) {
        throw AuthException('No authenticated Google account found. Please sign in.');
      }
    }

    return AuthenticatedHttpClient(() async {
      final headers = await _currentUser!.authHeaders;
      return headers;
    });
  }

  Future<void> _saveUserMetadata(GoogleSignInAccount account) async {
    await _secureStorage.write(key: _keyUserEmail, value: account.email);
    await _secureStorage.write(key: _keyUserId, value: account.id);
    if (account.displayName != null) {
      await _secureStorage.write(
        key: _keyUserDisplayName,
        value: account.displayName,
      );
    }
  }

  Future<void> _clearUserMetadata() async {
    await _secureStorage.delete(key: _keyUserEmail);
    await _secureStorage.delete(key: _keyUserId);
    await _secureStorage.delete(key: _keyUserDisplayName);
  }

  Future<String?> getCachedUserEmail() async {
    return await _secureStorage.read(key: _keyUserEmail);
  }
}
