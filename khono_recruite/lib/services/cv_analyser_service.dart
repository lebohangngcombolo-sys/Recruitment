import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/cv_analyser_models.dart';
import '../services/auth_service.dart';
import '../utils/api_endpoints.dart';

class CVAnalyserService {
  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    return {
      'Authorization': 'Bearer $token',
    };
  }

  Future<CVAnalyserUploadResponse> upload({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? jobDescription,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse(ApiEndpoints.cvAnalyserUpload);
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(headers);

    if (jobDescription != null && jobDescription.trim().isNotEmpty) {
      req.fields['job_description'] = jobDescription.trim();
    }

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _tryParseMediaType(contentType),
      ),
    );

    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    final decoded = _safeJsonDecode(body);

    if (resp.statusCode == 200 || resp.statusCode == 202) {
      return CVAnalyserUploadResponse.fromJson(
          Map<String, dynamic>.from(decoded as Map));
    }

    throw Exception(_extractError(decoded, resp.statusCode));
  }

  Future<CVAnalyserStatusResponse> getStatus(String analysisId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(ApiEndpoints.cvAnalyserStatus(analysisId));

    final resp = await http.get(uri, headers: headers);
    final decoded = _safeJsonDecode(resp.body);

    if (resp.statusCode == 200) {
      return CVAnalyserStatusResponse.fromJson(
          Map<String, dynamic>.from(decoded as Map));
    }

    throw Exception(_extractError(decoded, resp.statusCode));
  }

  Future<CVAnalyserResult> getResult(String analysisId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(ApiEndpoints.cvAnalyserResult(analysisId));

    final resp = await http.get(uri, headers: headers);
    final decoded = _safeJsonDecode(resp.body);

    if (resp.statusCode == 200) {
      return CVAnalyserResult.fromJson(
          Map<String, dynamic>.from(decoded as Map));
    }

    throw Exception(_extractError(decoded, resp.statusCode));
  }

  /// Polls until completed/failed, with exponential backoff (2s -> 30s).
  Future<CVAnalyserResult> uploadAndPoll({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? jobDescription,
    Duration timeout = const Duration(minutes: 5),
    void Function(CVAnalyserStatusResponse status)? onStatus,
  }) async {
    final uploadResp = await upload(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      jobDescription: jobDescription,
    );

    final analysisId = uploadResp.analysisId;
    final start = DateTime.now();
    var delay = const Duration(seconds: 2);

    while (DateTime.now().difference(start) < timeout) {
      final status = await getStatus(analysisId);
      onStatus?.call(status);

      switch (status.status) {
        case 'completed':
          return await getResult(analysisId);
        case 'failed':
          throw Exception('Analysis failed');
        case 'pending':
        case 'processing':
          await Future.delayed(delay);
          final next = delay.inSeconds * 2;
          delay = Duration(seconds: next > 30 ? 30 : next);
          break;
        default:
          await Future.delayed(delay);
          break;
      }
    }

    throw TimeoutException('Analysis timeout', timeout);
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'detail': body};
    }
  }

  String _extractError(dynamic decoded, int status) {
    if (decoded is Map && decoded['detail'] != null) {
      return decoded['detail'].toString();
    }
    if (decoded is Map && decoded['error'] != null) {
      return decoded['error'].toString();
    }
    return 'Request failed ($status)';
  }

  MediaType? _tryParseMediaType(String contentType) {
    try {
      final trimmed = contentType.trim();
      if (trimmed.isEmpty) return null;
      return MediaType.parse(trimmed);
    } catch (_) {
      return null;
    }
  }
}
