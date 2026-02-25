import 'dart:convert';
import 'dart:io' if (dart.library.html) 'package:khono_recruite/io_stub.dart' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:khono_recruite/utils/api_endpoints.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  /// Cached display name so the candidate dashboard can show it on first paint after login.
  static String? _cachedDisplayName;
  static String? getCachedDisplayName() => _cachedDisplayName;
  static void setCachedDisplayName(String? name) {
    _cachedDisplayName = name;
  }

  static String? _parseDisplayNameFromResponse(Map<String, dynamic> response) {
    final candidateProfile = response['candidate_profile'];
    final user = response['user'] ?? response;
    final profile = user['profile'] is Map ? user['profile'] as Map : null;
    String? displayName;
    if (candidateProfile != null &&
        candidateProfile['full_name']?.toString().trim().isNotEmpty == true) {
      displayName = candidateProfile['full_name'].toString().trim();
    }
    if (displayName == null || displayName.isEmpty) {
      final fullName = profile?['full_name']?.toString().trim();
      if (fullName != null && fullName.isNotEmpty) displayName = fullName;
    }
    if ((displayName == null || displayName.isEmpty) && profile != null) {
      final first = profile['first_name']?.toString() ?? '';
      final last = profile['last_name']?.toString() ?? '';
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) displayName = combined;
    }
    return (displayName != null && displayName.isNotEmpty) ? displayName : null;
  }

  // ----------------- REGISTER -----------------
  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    // Only keep email and password
    final requestData = {
      "email": data["email"],
      "password": data["password"],
    };

    final response = await http.post(
      Uri.parse(ApiEndpoints.register),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestData),
    );

    final body = jsonDecode(response.body);

    return {
      "status": response.statusCode, // HTTP status code
      "body": body, // decoded response
    };
  }

  // ----------------- RESEND VERIFICATION CODE -----------------
  static Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.resendVerification),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(decoded as Map);
      }
      return {'error': decoded['error'] ?? decoded['message'] ?? 'Failed to resend code'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ----------------- VERIFY EMAIL -----------------
  static Future<Map<String, dynamic>> verifyEmail(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.verify),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    final decoded = jsonDecode(response.body);

    if (decoded.containsKey('access_token')) {
      await clearAuthState();
      final access = decoded['access_token'].toString();
      final refresh = decoded['refresh_token']?.toString();
      await saveTokens(access, refresh);
    }
    return decoded;
  }

  // Example: fetch stored user info from shared preferences
  static Future<int> getUserId() async {
    final user = await getUserInfo();
    if (user != null) {
      return user['id'] as int;
    }
    throw Exception('User not logged in');
  }

  // ----------------- LOGIN (UPDATED WITH MFA) -----------------
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // ≡ƒåò Check if MFA is required
      if (data['mfa_required'] == true) {
        // ≡ƒåò FIX: Convert user_id to string to prevent type errors
        final userId = data['user_id']?.toString() ?? '';

        return {
          'success': true,
          'mfa_required': true,
          'mfa_session_token': data['mfa_session_token'],
          'user_id': userId, // ≡ƒåò Now guaranteed to be string
          'message': data['message'],
        };
      }

      // Clear any previous user's session so this login is a fresh session.
      await clearAuthState();
      await saveTokens(
        data['access_token'].toString(),
        data['refresh_token']?.toString(),
      );
      await saveUserInfo(data['user'] ?? {});

      return {
        'success': true,
        'access_token': data['access_token'],
        'refresh_token': data['refresh_token'],
        'role': data['user']['role'],
        'dashboard': data['dashboard'],
      };
    } else {
      return {'success': false, 'message': data['error'] ?? 'Login failed'};
    }
  }

  static Future<Map<String, dynamic>> verifyMfaLogin(
      String mfaSessionToken, String token) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.mfaLogin), // <-- fixed
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mfa_session_token': mfaSessionToken,
        'token': token,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await clearAuthState();
      await saveTokens(
        data['access_token'].toString(),
        data['refresh_token']?.toString(),
      );
      await saveUserInfo(data['user'] ?? {});

      return {
        'success': true,
        'access_token': data['access_token'],
        'refresh_token': data['refresh_token'],
        'user': data['user'],
        'dashboard': data['dashboard'],
        'used_backup_code': data['used_backup_code'] ?? false,
        'message': data['message'],
      };
    } else {
      return {
        'success': false,
        'message': data['error'] ?? 'MFA verification failed'
      };
    }
  }

  // ----------------- LOGOUT -----------------
  /// Logs out on the server (when token is valid) and always clears local auth state.
  /// Returns true so the UI can navigate away; 422 (e.g. expired token) is treated as success.
  static Future<bool> logout() async {
    try {
      final token = await getAccessToken();
      await http.post(
        Uri.parse(ApiEndpoints.logout),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      // Clear local state regardless of status (200 or 422) so user is always "logged out" locally.
      await clearAuthState();
      return true;
    } catch (_) {
      await clearAuthState();
      return true;
    }
  }

// ---------- SOCIAL LOGIN URL GETTERS ----------
  static String get googleOAuthUrl => ApiEndpoints.googleOAuth;
  static String get githubOAuthUrl => ApiEndpoints.githubOAuth;

  static Future<Map<String, dynamic>> loginWithGoogle() async {
    // Launch Google OAuth in a new tab or popup
    final result = await FlutterWebAuth.authenticate(
      url: ApiEndpoints.googleOAuth,
      callbackUrlScheme: "myapp", // match your URL scheme
    );

    // Parse the redirected URL with tokens
    final uri = Uri.parse(result);
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    final role = uri.queryParameters['role'];

    if (accessToken != null && role != null) {
      await AuthService.clearAuthState();
      await AuthService.storeTokens(accessToken, refreshToken, role);
    }

    // Return success status and info
    return {
      'success': accessToken != null,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'role': role,
    };
  }

  static Future<Map<String, dynamic>> loginWithGithub() async {
    final result = await FlutterWebAuth.authenticate(
      url: ApiEndpoints.githubOAuth,
      callbackUrlScheme: "myapp",
    );

    final uri = Uri.parse(result);
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    final role = uri.queryParameters['role'];
    final dashboard = uri.queryParameters['dashboard'];

    if (accessToken != null) {
      await clearAuthState();
      await saveTokens(accessToken, refreshToken);
    }

    return {
      'success': accessToken != null,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'role': role,
      'dashboard': dashboard,
    };
  }

  // ----------------- FORGOT PASSWORD -----------------
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.forgotPassword),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return jsonDecode(response.body);
  }

  // ----------------- RESET PASSWORD -----------------
  static Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.resetPassword),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token, "new_password": newPassword}),
    );
    return jsonDecode(response.body);
  }

  // ----------------- GET CURRENT USER -----------------
  static Future<Map<String, dynamic>> getCurrentUser({String? token}) async {
    token ??= await getAccessToken();

    final response = await http.get(
      Uri.parse(ApiEndpoints.currentUser),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    // If token expired, try refresh and retry once
    if (response.statusCode == 401) {
      final newToken = await refreshAccessToken();
      if (newToken != null) {
        return getCurrentUser(token: newToken);
      }
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          body['unauthorized'] = true;
          body['error'] = body['msg'] ?? body['error'] ?? 'Session expired. Please log in again.';
          return body;
        }
      } catch (_) {}
      return {'error': 'Session expired. Please log in again.', 'unauthorized': true};
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      return {'error': 'Invalid response', 'unauthorized': true};
    }

    // Server might return 200 with error body (e.g. "Token has expired"); don't treat as success
    final isErrorResponse = (data['unauthorized'] == true) ||
        (data['msg']?.toString().toLowerCase().contains('expired') == true) ||
        (data['error'] != null && !data.containsKey('user'));
    if (isErrorResponse) {
      final newToken = await refreshAccessToken();
      if (newToken != null) {
        return getCurrentUser(token: newToken);
      }
      data['unauthorized'] = true;
      data['error'] = data['msg'] ?? data['error'] ?? 'Session expired. Please log in again.';
      return data;
    }

    final name = _parseDisplayNameFromResponse(data);
    if (name != null) {
      setCachedDisplayName(name);
      persistDisplayName(name);
    }
    return data;
  }

  // ----------------- CV PARSING -----------------
  static Future<Map<String, dynamic>> parseCV({
    required String token,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      if (token.trim().isEmpty) {
        return {
          'error': 'Not signed in. Please log in again to parse your CV.',
        };
      }

      // Server accepts JWT in header or in query (access_token) for CORS/proxy cases
      final uri = Uri.parse(ApiEndpoints.parserCV).replace(
        queryParameters: {'access_token': token},
      );
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'cv',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      if (response.statusCode == 401) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>?;
          final msg = body?['error'] ?? body?['message'] ?? 'Session expired or invalid.';
          return {'error': '$msg Please log in again.', 'unauthorized': true};
        } catch (_) {
          return {
            'error': 'Session expired or invalid. Please log in again.',
            'unauthorized': true,
          };
        }
      }
      if (response.statusCode == 403) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>?;
          final msg = body?['error'] ?? 'You do not have permission to use this feature.';
          return {'error': msg, 'forbidden': true};
        } catch (_) {
          return {'error': 'You do not have permission to parse CV.', 'forbidden': true};
        }
      }
      return {
        'error': 'Failed to parse CV: ${response.statusCode}',
      };
    } catch (e) {
      return {'error': 'Error parsing CV: $e'};
    }
  }

// ----------------- COMPLETE ENROLLMENT -----------------
  static Future<Map<String, dynamic>> completeEnrollment(
    String token,
    Map<String, dynamic> data, {
    File? cvFile,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiEndpoints.enrollment),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // --------------------
      // Attach fields
      // --------------------
      data.forEach((key, value) {
        if (value == null) return;

        if (value is List || value is Map) {
          request.fields[key] = jsonEncode(value);
        } else {
          request.fields[key] = value.toString();
        }
      });

      // --------------------
      // Optional CV upload (fromPath not supported on web)
      // --------------------
      if (cvFile != null && !kIsWeb) {
        request.files.add(
          await http.MultipartFile.fromPath('cv', cvFile.path),
        );
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      final decoded = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200) {
        return decoded;
      } else {
        final serverMessage = decoded is Map
            ? (decoded['error'] ?? decoded['message']?.toString())
            : null;
        return {
          'error': serverMessage ?? 'Enrollment failed (${streamedResponse.statusCode})',
          'details': decoded,
        };
      }
    } catch (e) {
      return {'error': 'Enrollment error: $e'};
    }
  }

  // ----------------- ADMIN ENROLL USER -----------------
  static Future<Map<String, dynamic>> enrollUser(
      String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.adminEnroll),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ----------------- CHANGE PASSWORD (FIRST LOGIN) -----------------
  static Future<Map<String, dynamic>> changePassword({
    required String tempPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await getAccessToken();

    final response = await http.post(
      Uri.parse(ApiEndpoints.changePassword),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "temporary_password": tempPassword,
        "new_password": newPassword,
        "confirm_password": confirmPassword,
      }),
    );

    return jsonDecode(response.body);
  }

  // ----------------- TOKEN HELPERS -----------------
  static Future<void> saveTokens(
      String accessToken, String? refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
    await _persistTokensToPrefs(accessToken, refreshToken);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<void> deleteTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token');
    await clearPersistedDisplayName();
  }

  /// Clear all auth state (tokens, role, user, cache). Call before saving new tokens on login so each new user gets a fresh session. Also call when opening job details from landing so guest users don't see a previous user's session.
  static Future<void> clearAuthState() async {
    await deleteTokens();
    setCachedDisplayName(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    await prefs.remove('user');
  }

// ----------------- SAVE TOKEN -----------------
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
    await _persistTokensToPrefs(token, null);
  }

  // ----------------- AUTHORIZED REQUEST HELPERS -----------------
  static http.Response _missingTokenResponse() {
    return http.Response(
      jsonEncode({"error": "Missing access token"}),
      401,
      headers: {"Content-Type": "application/json"},
    );
  }

  static Future<http.Response> authorizedGet(String url) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return _missingTokenResponse();
    }
    return http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
  }

  static Future<http.Response> authorizedPost(
      String url, Map<String, dynamic> body) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return _missingTokenResponse();
    }
    return http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> authorizedPut(
      String url, Map<String, dynamic> data) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return _missingTokenResponse();
    }
    return http.put(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );
  }

  static Future<http.Response> authorizedDelete(String url) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return _missingTokenResponse();
    }
    return http.delete(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
  }

  // Save user info (JSON string) in SharedPreferences
  static Future<void> saveUserInfo(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  /// Persist display name so it survives token expiry until re-login.
  static const String _keyDisplayName = 'display_name';
  static Future<void> persistDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, name);
  }
  static Future<String?> getPersistedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDisplayName);
  }
  static Future<void> clearPersistedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDisplayName);
  }

// Retrieve saved user info
  static Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  /// Use refresh token to get a new access token. Returns new access token or null on failure.
  static Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.refresh),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['access_token'] != null) {
          final newToken = data['access_token'].toString();
          await saveToken(newToken);
          return newToken;
        }
      }
    } catch (_) {}
    return null;
  }

  // ----------------- GET USER PROFILE -----------------
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.currentUser), // Using existing endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final name = _parseDisplayNameFromResponse(data);
          if (name != null) setCachedDisplayName(name);
        }
        return data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  // ----------------- STORE TOKENS WITH ROLE -----------------
  static Future<void> storeTokens(
      String accessToken, String? refreshToken, String role) async {
    await saveTokens(accessToken, refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
  }

  static Future<void> _persistTokensToPrefs(
      String accessToken, String? refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('token', accessToken);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

// Retrieve stored role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  /// Store job user intended to apply to before being sent to login. Full job stored so after login we can open job details. Cleared after apply or dismiss.
  static const String _keyPendingApplyJob = 'pending_apply_job';
  static Future<void> setPendingApplyJob(Map<String, dynamic> job) async {
    final prefs = await SharedPreferences.getInstance();
    if (job['id'] == null) return;
    await prefs.setString(_keyPendingApplyJob, jsonEncode(job));
  }
  static Future<Map<String, dynamic>?> getPendingApplyJob() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyPendingApplyJob);
    if (s == null || s.isEmpty) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
  static Future<void> clearPendingApplyJob() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingApplyJob);
  }

  // ≡ƒåò MFA MANAGEMENT METHODS
  static Future<Map<String, dynamic>> enableMfa() async {
    final token = await getAccessToken();
    final response = await http.post(
      Uri.parse(ApiEndpoints.enableMfa),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyMfaSetup(String token) async {
    final authToken = await getAccessToken();
    final response = await http.post(
      Uri.parse(ApiEndpoints.verifyMfaSetup),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'token': token}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> disableMfa(String password) async {
    final authToken = await getAccessToken();
    final response = await http.post(
      Uri.parse(ApiEndpoints.disableMfa),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getMfaStatus() async {
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.mfaStatus),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getBackupCodes() async {
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.backupCodes),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> regenerateBackupCodes() async {
    final token = await getAccessToken();
    final response = await http.post(
      Uri.parse(ApiEndpoints.regenerateBackupCodes),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }
}
