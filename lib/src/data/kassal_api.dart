import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/product.dart';

/// A failure talking to Kassalapp, carrying a message meant for the user.
class KassalException implements Exception {
  KassalException(this.message, {this.statusCode, this.isAuthFailure = false});

  final String message;
  final int? statusCode;
  final bool isAuthFailure;

  @override
  String toString() => message;
}

/// Client for the Kassalapp API (https://kassal.app/api).
///
/// Kassalapp indexes Norwegian grocery products, which is why it is the source
/// here: barcodes and product names in Norwegian stores resolve reliably,
/// where international databases mostly do not.
class KassalApi {
  KassalApi({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = 'https://kassal.app/api/v1';

  /// Reads the current API token. A callback rather than a value so the client
  /// picks up a token entered in settings without being rebuilt.
  final Future<String?> Function() tokenProvider;

  final http.Client _client;

  /// Hobby-tier accounts are limited to 60 requests per minute; searches are
  /// debounced in the UI and this timeout keeps a stalled request from
  /// blocking the screen.
  static const Duration timeout = Duration(seconds: 15);

  /// Full-text product search, used by the search bar.
  Future<List<Product>> searchProducts(
    String query, {
    int size = 25,
    bool uniqueOnly = true,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final json = await _get('/products', {
      'search': trimmed,
      'size': '$size',
      // Collapse the same article sold by several stores into one hit.
      if (uniqueOnly) 'unique': '1',
      'sort': 'name_asc',
    });

    final data = json['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Looks up a scanned barcode.
  ///
  /// The endpoint returns one entry per store carrying the article. They are
  /// merged into a single product so the nutrition declaration survives even
  /// when the cheapest listing omits it. Returns null when the barcode is not
  /// in the database.
  Future<Product?> productByEan(String ean) async {
    final normalised = ean.trim();
    if (normalised.isEmpty) return null;

    final Map<String, dynamic> json;
    try {
      json = await _get('/products/ean/$normalised', const {});
    } on KassalException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }

    final data = json['data'];
    if (data is! Map) return null;

    final rawProducts = data['products'];
    if (rawProducts is! List || rawProducts.isEmpty) return null;

    final variants = rawProducts
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList();

    // The EAN response also carries a top-level declaration that is often more
    // complete than any single store's listing.
    final shared = Product.fromJson({
      'id': variants.first.id,
      'name': variants.first.name,
      'ean': normalised,
      'nutrition': data['nutrition'],
      'allergens': data['allergens'],
    });

    var best = variants.first;
    for (final variant in variants.skip(1)) {
      best = best.mergedWith(variant);
    }
    return best.mergedWith(shared);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw KassalException(
        'Mangler API-nøkkel for Kassalapp. Legg den inn under Innstillinger.',
        isAuthFailure: true,
      );
    }

    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw KassalException('Tidsavbrudd — sjekk nettforbindelsen.');
    } on SocketException {
      throw KassalException('Ingen nettforbindelse.');
    } on http.ClientException catch (e) {
      throw KassalException('Nettverksfeil: ${e.message}');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw KassalException(
        'API-nøkkelen ble avvist. Sjekk nøkkelen under Innstillinger.',
        statusCode: response.statusCode,
        isAuthFailure: true,
      );
    }
    if (response.statusCode == 429) {
      throw KassalException(
        'For mange forespørsler mot Kassalapp. Vent litt og prøv igjen.',
        statusCode: 429,
      );
    }
    if (response.statusCode >= 400) {
      throw KassalException(
        'Kassalapp svarte med feil (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } on FormatException {
      throw KassalException('Fikk et uventet svar fra Kassalapp.');
    }
  }

  void dispose() => _client.close();
}
