import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offer.dart';
import '../utils/api_endpoints.dart';
import 'auth_service.dart';

class OfferService {
  final Map<String, String> headers = {'Content-Type': 'application/json'};

  // ---------- OFFERS ----------
  Future<List<Offer>> getAllOffers() async {
    final res = await _get(ApiEndpoints.getAllOffers);
    return (res as List).map((e) => Offer.fromJson(e)).toList();
  }

  Future<Offer> getOffer(int offerId) async {
    final res = await _get(ApiEndpoints.getOffer(offerId));
    return Offer.fromJson(res);
  }

  Future<Offer> draftOffer(Map<String, dynamic> data) async {
    final res = await _post(ApiEndpoints.draftOffer,
        data: data, expectedStatusCode: 201);
    return Offer.fromJson(res);
  }

  Future<Offer> reviewOffer(int offerId, String comments) async {
    final res = await _post(ApiEndpoints.reviewOffer(offerId),
        data: {'review_comments': comments});
    return Offer.fromJson(res);
  }

  Future<Offer> approveOffer(int offerId) async {
    final res = await _post(ApiEndpoints.approveOffer(offerId));
    return Offer.fromJson(res);
  }

  Future<Offer> rejectOffer(int offerId, String reason) async {
    final res = await _post(ApiEndpoints.rejectOffer(offerId),
        data: {'reason': reason});
    return Offer.fromJson(res);
  }

  Future<Offer> expireOffer(int offerId) async {
    final res = await _post(ApiEndpoints.expireOffer(offerId));
    return Offer.fromJson(res);
  }

  Future<Offer> signOffer(int offerId, {String? token}) async {
    final t = token ?? await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiEndpoints.signOffer(offerId)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      },
    );

    if (res.statusCode == 200) {
      return Offer.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to sign offer: ${res.body}');
    }
  }

  Future<List<Offer>> getOffersByStatus(String status) async {
    final formattedStatus =
        status[0].toUpperCase() + status.substring(1).toLowerCase();
    final res = await _get(ApiEndpoints.getOffersByStatus(formattedStatus));
    return (res as List).map((e) => Offer.fromJson(e)).toList();
  }

  Future<List<Offer>> getCandidateOffers(int candidateId) async {
    final res = await _get(ApiEndpoints.getCandidateOffers(candidateId));
    return (res as List).map((e) => Offer.fromJson(e)).toList();
  }

  // ---------- MY OFFERS (current logged-in candidate) ----------
  Future<List<Offer>> getMyOffers() async {
    final res = await _get(ApiEndpoints.myOffer());
    return (res as List).map((e) => Offer.fromJson(e)).toList();
  }

  // ---------- ANALYTICS ----------
  Future<Map<String, int>> getOfferAnalytics() async {
    final res = await _get(ApiEndpoints.getOfferAnalytics);
    return (res as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as int));
  }

  // ---------- ROLE-BASED CONVENIENCE ----------
  Future<List<Offer>> getOffersForRole(
      {required String role, int? candidateId}) async {
    switch (role.toLowerCase()) {
      case 'admin':
        return getAllOffers();
      case 'hiring_manager':
        return getOffersByStatus('Draft');
      case 'hr':
        return getOffersByStatus('Reviewed');
      case 'candidate':
        return getMyOffers();
      default:
        throw Exception('Unknown role: $role');
    }
  }

  // ---------- PRIVATE HELPERS ----------
  Future<dynamic> _get(String url, {int expectedStatusCode = 200}) async {
    final token = await AuthService.getAccessToken();
    final res = await http.get(Uri.parse(url),
        headers: {...headers, 'Authorization': 'Bearer $token'});
    return _handleResponse(res, expectedStatusCode: expectedStatusCode);
  }

  Future<dynamic> _post(String url,
      {Map<String, dynamic>? data, int expectedStatusCode = 200}) async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse(url),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: data != null ? json.encode(data) : null,
    );
    return _handleResponse(res, expectedStatusCode: expectedStatusCode);
  }

  dynamic _handleResponse(http.Response res, {int expectedStatusCode = 200}) {
    final decoded = json.decode(res.body);
    if (res.statusCode == expectedStatusCode) return decoded;
    throw Exception('Request failed [${res.statusCode}]: ${res.body}');
  }
}
