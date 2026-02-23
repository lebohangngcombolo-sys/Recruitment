import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/api_endpoints.dart';
import 'auth_service.dart';

class JobService {
  Future<Map<String, dynamic>> createJob(Map<String, dynamic> jobData) async {
    final token = await AuthService.getAccessToken();
    final response = await http.post(
      Uri.parse(ApiEndpoints.createJob),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(jobData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create job: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateJob(
      String jobId, Map<String, dynamic> jobData) async {
    final token = await AuthService.getAccessToken();
    final response = await http.put(
      Uri.parse(ApiEndpoints.updateJob(int.parse(jobId))),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(jobData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update job: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getJob(String jobId) async {
    final token = await AuthService.getAccessToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.getJobById(int.parse(jobId))),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get job: ${response.body}');
    }
  }

  Future<List<dynamic>> getAllJobs() async {
    final token = await AuthService.getAccessToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.adminJobs),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get jobs: ${response.body}');
    }
  }

  Future<void> deleteJob(String jobId) async {
    final token = await AuthService.getAccessToken();
    final response = await http.delete(
      Uri.parse(ApiEndpoints.deleteJob(int.parse(jobId))),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete job: ${response.body}');
    }
  }
}
