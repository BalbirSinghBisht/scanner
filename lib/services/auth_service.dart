import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import 'settings_repository.dart';

/// Custom HTTP Client that attaches Google authorization headers, API key, and ensures valid token
class AuthenticatedHttpClient extends http.BaseClient {
  final Future<void> Function()? _onBeforeRequest;
  final Future<Map<String, String>> Function() _headerProvider;
  final http.Client _inner = http.Client();

  AuthenticatedHttpClient(
    this._headerProvider, {
    this._onBeforeRequest,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final onBefore = _onBeforeRequest;
    if (onBefore != null) {
      await onBefore();
    }
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
  final SettingsRepository _settings = SettingsRepository.instance;

  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserDisplayName = 'auth_user_display_name';

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _directAccessToken;
  String? _directRefreshToken;
  DateTime? _tokenExpiry;
  String? _apiKey;
  Timer? _renewalTimer;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated =>
      _currentUser != null ||
      (_directAccessToken != null && _directAccessToken!.isNotEmpty);
  String? get userEmail => _currentUser?.email ?? '5 TB Google Drive';
  String? get userDisplayName =>
      _currentUser?.displayName ?? 'balbirbisht560@gmail.com (5 TB)';
  String? get directAccessToken => _directAccessToken;
  String? get directRefreshToken => _directRefreshToken;
  DateTime? get tokenExpiry => _tokenExpiry;
  String? get apiKey => _apiKey;

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

  /// Restores signed-in account silently on app launch or restores direct developer token
  Future<GoogleSignInAccount?> restoreSession({String? clientId}) async {
    try {
      _apiKey = await _settings.getGoogleApiKey();
      _directAccessToken = await _settings.getDirectAccessToken();
      _directRefreshToken = await _settings.getDirectRefreshToken();
      _tokenExpiry = await _settings.getTokenExpiry();

      // Proactively renew direct access token if close to expiration
      await ensureValidToken();

      // Start background auto-renewal timer (checks every 5 minutes)
      _startAutoRenewalTimer();

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

  /// Proactively refreshes the direct access token if expired or expiring within 5 minutes
  Future<void> ensureValidToken() async {
    if (_directRefreshToken != null && _directRefreshToken!.isNotEmpty) {
      final now = DateTime.now();
      // If expiry is unknown or expires within 5 minutes, renew immediately
      if (_tokenExpiry == null || now.add(const Duration(minutes: 5)).isAfter(_tokenExpiry!)) {
        await refreshDirectAccessToken();
      }
    }
  }

  /// Automatically exchanges the refresh token for a fresh access token without user prompt
  Future<String?> refreshDirectAccessToken() async {
    _directRefreshToken ??= await _settings.getDirectRefreshToken();
    if (_directRefreshToken == null || _directRefreshToken!.isEmpty) {
      return null;
    }

    try {
      final clientId = await _settings.getCustomOAuthClientId();
      final clientSecret = await _settings.getCustomOAuthClientSecret();

      http.Response response;
      if (clientId != null &&
          clientId.isNotEmpty &&
          clientSecret != null &&
          clientSecret.isNotEmpty) {
        response = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'refresh_token': _directRefreshToken!,
            'grant_type': 'refresh_token',
          },
        );
      } else {
        response = await http.post(
          Uri.parse('https://developers.google.com/oauthplayground/refreshAccessToken'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token_uri': 'https://oauth2.googleapis.com/token',
            'refresh_token': _directRefreshToken,
          }),
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          _directAccessToken = newAccessToken;
          // Set expiry 3 minutes before actual expiration for safety
          _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 180));

          await _settings.saveDirectAccessToken(newAccessToken);
          await _settings.saveTokenExpiry(_tokenExpiry);

          debugPrint('Successfully auto-renewed Google Drive access token. Next expiry: $_tokenExpiry');
          return newAccessToken;
        }
      } else {
        debugPrint('Token auto-renewal failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error auto-renewing access token: $e');
    }
    return null;
  }

  /// Starts a periodic background timer that automatically renews the token before it expires
  void _startAutoRenewalTimer() {
    _renewalTimer?.cancel();
    _renewalTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await ensureValidToken();
    });
  }

  /// Sets a direct OAuth 2.0 access token and refresh token
  Future<void> setDirectTokens({
    required String? accessToken,
    String? refreshToken,
  }) async {
    _directAccessToken = accessToken;
    _directRefreshToken = refreshToken;
    await _settings.saveDirectAccessToken(accessToken);
    await _settings.saveDirectRefreshToken(refreshToken);
    if (refreshToken != null) {
      await refreshDirectAccessToken();
    }
    _startAutoRenewalTimer();
  }

  /// Sets Google Cloud API key
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    await _settings.saveGoogleApiKey(key);
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
    _renewalTimer?.cancel();
    try {
      await _signInInstance.signOut();
    } catch (_) {}
    _currentUser = null;
    _directAccessToken = null;
    _directRefreshToken = null;
    _tokenExpiry = null;
    await _settings.saveDirectAccessToken(null);
    await _settings.saveDirectRefreshToken(null);
    await _settings.saveTokenExpiry(null);
    await _clearUserMetadata();
  }

  /// Completely revokes access permissions
  Future<void> disconnect() async {
    await signOut();
    try {
      await _signInInstance.disconnect();
    } catch (_) {}
  }

  /// Returns an authenticated HTTP Client suitable for Google Drive API calls
  Future<http.Client> getAuthenticatedClient() async {
    // 1. Prioritize Google Sign-In user account (consumes user's 5 TB Drive storage)
    if (_currentUser == null) {
      await restoreSession();
    }
    if (_currentUser != null) {
      return AuthenticatedHttpClient(() async {
        return await _currentUser!.authHeaders;
      });
    }

    // 2. Direct developer OAuth token (for user's 5 TB account)
    _directAccessToken ??= await _settings.getDirectAccessToken();
    _directRefreshToken ??= await _settings.getDirectRefreshToken();
    if (_directAccessToken != null && _directAccessToken!.isNotEmpty) {
      return AuthenticatedHttpClient(
        () async {
          return <String, String>{
            'Authorization': 'Bearer $_directAccessToken',
          };
        },
        onBeforeRequest: () async {
          await ensureValidToken();
        },
      );
    }

    // 3. Fallback: Service Account credentials
    final saJson = await _settings.getServiceAccountJson();
    if (saJson != null && saJson.isNotEmpty) {
      try {
        final credentials = ServiceAccountCredentials.fromJson(saJson);
        final scopes = [
          'https://www.googleapis.com/auth/drive',
          'https://www.googleapis.com/auth/drive.file',
        ];
        return await clientViaServiceAccount(credentials, scopes);
      } catch (e) {
        debugPrint('Error creating Service Account client: $e');
      }
    }

    throw AuthException(
      'Google Drive requires connecting your 5 TB Google account to allocate storage quota.',
    );
  }

  /// Tests if current access credentials are valid by querying Google Drive /about endpoint
  Future<bool> validateCurrentToken() async {
    try {
      if (_currentUser != null) {
        final headers = await _currentUser!.authHeaders;
        final res = await http.get(
          Uri.parse('https://www.googleapis.com/drive/v3/about?fields=user'),
          headers: headers,
        );
        return res.statusCode == 200;
      }

      _directAccessToken ??= await _settings.getDirectAccessToken();
      if (_directAccessToken != null && _directAccessToken!.isNotEmpty) {
        final res = await http.get(
          Uri.parse('https://www.googleapis.com/drive/v3/about?fields=user'),
          headers: {'Authorization': 'Bearer $_directAccessToken'},
        );
        if (res.statusCode == 200) return true;
        if (res.statusCode == 401 && _directRefreshToken != null) {
          final refreshed = await refreshDirectAccessToken();
          if (refreshed != null && refreshed.isNotEmpty) {
            final retryRes = await http.get(
              Uri.parse('https://www.googleapis.com/drive/v3/about?fields=user'),
              headers: {'Authorization': 'Bearer $refreshed'},
            );
            return retryRes.statusCode == 200;
          }
        }
        return false;
      }

      final saJson = await _settings.getServiceAccountJson();
      if (saJson != null && saJson.isNotEmpty) {
        final client = await getAuthenticatedClient();
        final res = await client.get(
          Uri.parse('https://www.googleapis.com/drive/v3/about?fields=user'),
        );
        return res.statusCode == 200;
      }

      return false;
    } catch (_) {
      return false;
    }
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
