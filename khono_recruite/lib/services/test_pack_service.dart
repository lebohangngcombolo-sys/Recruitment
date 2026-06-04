import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:http/http.dart' as http;
import '../models/test_pack.dart';
import '../utils/api_endpoints.dart';
import 'auth_service.dart';

class TestPackService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<TestPack>> getTestPacks({String? category}) async {
    final uri = category != null && category.isNotEmpty
        ? Uri.parse(ApiEndpoints.getTestPacks).replace(
            queryParameters: {'category': category},
          )
        : Uri.parse(ApiEndpoints.getTestPacks);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final list = body?['test_packs'] as List<dynamic>? ?? [];
      return list
          .map((e) => TestPack.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw Exception('Failed to load test packs: ${response.body}');
  }

  Future<TestPack> getTestPack(int id) async {
    final response = await http.get(
      Uri.parse(ApiEndpoints.getTestPackById(id)),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return TestPack.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw Exception('Failed to load test pack: ${response.body}');
  }

  Future<TestPack> createTestPack(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.createTestPack),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return TestPack.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw Exception('Failed to create test pack: ${response.body}');
  }

  Future<TestPack> updateTestPack(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse(ApiEndpoints.updateTestPack(id)),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return TestPack.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw Exception('Failed to update test pack: ${response.body}');
  }

  Future<void> deleteTestPack(int id) async {
    final response = await http.delete(
      Uri.parse(ApiEndpoints.deleteTestPack(id)),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete test pack: ${response.body}');
    }
  }
}
