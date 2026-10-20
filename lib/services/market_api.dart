import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/product.dart';

const _searchApiUrl = String.fromEnvironment(
  'SEARCH_API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
const _showApiUrl = String.fromEnvironment(
  'SHOW_API_URL',
  defaultValue: 'http://10.0.2.2:9000',
);

class MarketApiException implements Exception {
  const MarketApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FeaturedResponse {
  const FeaturedResponse({required this.products, required this.errors});

  final List<Product> products;
  final List<String> errors;
}

class MarketApi {
  MarketApi()
      : _searchBase = _baseUri(_searchApiUrl),
        _showBase = _baseUri(_showApiUrl);

  final Uri _searchBase;
  final Uri _showBase;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  static const _stores = [
    _Store(
      name: 'Daraz',
      baseUrl: 'https://www.daraz.pk',
      featuredPath: '/daraz_showing',
      featuredKey: 'Daraz_show',
      searchKey: 'items_of_daraz_searched',
      titleKey: 'Titles',
      linkKey: 'links',
      priceKey: 'Price',
      imageKey: 'Images',
    ),
    _Store(
      name: 'Czone',
      baseUrl: 'https://www.czone.com.pk',
      featuredPath: '/computer_zone_showing',
      featuredKey: 'cz_items_show',
      searchKey: 'items_of_cz_seached',
      titleKey: 'Title',
      linkKey: 'Link',
      priceKey: 'Price',
      imageKey: 'Images',
    ),
    _Store(
      name: 'ZAH Computers',
      baseUrl: 'https://zahcomputers.pk',
      featuredPath: '/zahcomputers_showing',
      featuredKey: 'zah_items_show',
      searchKey: 'items_zah',
      titleKey: 'Tittle',
      linkKey: 'Links',
      priceKey: 'Prices',
      imageKey: 'Image',
    ),
  ];

  Future<FeaturedResponse> getFeatured() async {
    final responses = await Future.wait(
      _stores.map((store) async {
        try {
          final payload = await _get(_showBase.resolve(store.featuredPath));
          return (
            products: _readProducts(payload[store.featuredKey], store),
            error: null as String?,
          );
        } on MarketApiException catch (error) {
          return (products: <Product>[], error: '${store.name}: ${error.message}');
        } on FormatException catch (error) {
          return (
            products: <Product>[],
            error: '${store.name}: invalid response (${error.message})',
          );
        }
      }),
    );
    final products = <Product>[];
    final errors = <String>[];
    for (final response in responses) {
      products.addAll(response.products);
      if (response.error != null) errors.add(response.error!);
    }
    if (products.isEmpty && errors.length == _stores.length) {
      throw MarketApiException(errors.join('\n'));
    }
    return FeaturedResponse(products: products, errors: errors);
  }

  Future<List<Product>> search(String query) async {
    final uri = _searchBase
        .resolve('/search')
        .replace(queryParameters: {'q': query});
    try {
      final payload = await _get(uri);
      final products = <Product>[];
      for (final store in _stores) {
        products.addAll(_readProducts(payload[store.searchKey], store));
      }
      return products;
    } on FormatException catch (error) {
      throw MarketApiException('The search service returned invalid data: $error');
    }
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final request = await _client.getUrl(uri).timeout(
            const Duration(seconds: 20),
          );
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final response = await request.close().timeout(
            const Duration(seconds: 240),
          );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _errorDetail(body);
        throw MarketApiException(
          detail.isEmpty
              ? 'The service returned HTTP ${response.statusCode}.'
              : detail,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      return decoded;
    } on MarketApiException {
      rethrow;
    } on TimeoutException {
      throw const MarketApiException(
        'The store search took too long. Please try again.',
      );
    } on SocketException catch (error) {
      throw MarketApiException('Could not reach the backend: ${error.message}');
    } on HttpException catch (error) {
      throw MarketApiException('Network request failed: ${error.message}');
    } on IOException catch (error) {
      throw MarketApiException('Network request failed: $error');
    } on FormatException {
      rethrow;
    }
  }

  List<Product> _readProducts(Object? value, _Store store) {
    if (value is! List) {
      throw FormatException('${store.name} did not return a product list.');
    }
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          Product(
            title: _readText(item[store.titleKey], 'Untitled product'),
            price: _readText(item[store.priceKey], 'Price unavailable'),
            store: store.name,
            link: _productUri(item[store.linkKey], store.baseUrl),
            image: _productUri(item[store.imageKey], store.baseUrl),
          ),
    ];
  }

  String _readText(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  Uri? _productUri(Object? value, String baseUrl) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    final resolved = uri.hasScheme ? uri : Uri.parse(baseUrl).resolveUri(uri);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    return resolved;
  }

  String _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] ?? decoded['error'];
        if (detail is String) return detail;
        if (detail != null) return detail.toString();
      }
    } on FormatException {
      return '';
    }
    return '';
  }

  static Uri _baseUri(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !parsed.hasAuthority ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw ArgumentError.value(value, 'API URL', 'Must be an HTTP(S) URL.');
    }
    return parsed;
  }

  void close() => _client.close(force: true);
}

class _Store {
  const _Store({
    required this.name,
    required this.baseUrl,
    required this.featuredPath,
    required this.featuredKey,
    required this.searchKey,
    required this.titleKey,
    required this.linkKey,
    required this.priceKey,
    required this.imageKey,
  });

  final String name;
  final String baseUrl;
  final String featuredPath;
  final String featuredKey;
  final String searchKey;
  final String titleKey;
  final String linkKey;
  final String priceKey;
  final String imageKey;
}
