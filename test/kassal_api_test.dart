import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_lens/src/data/kassal_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

KassalApi _apiReturning(
  String body, {
  int status = 200,
  String? token = 'test-token',
  void Function(http.Request request)? onRequest,
}) => KassalApi(
  tokenProvider: () async => token,
  client: MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

void main() {
  group('searchProducts', () {
    test('sends the bearer token and search query', () async {
      http.Request? captured;
      final api = _apiReturning(
        jsonEncode({'data': []}),
        onRequest: (r) => captured = r,
      );

      await api.searchProducts('havregryn');

      expect(captured!.headers['Authorization'], 'Bearer test-token');
      expect(captured!.url.queryParameters['search'], 'havregryn');
      expect(captured!.url.path, endsWith('/products'));
    });

    test('parses the result list', () async {
      final api = _apiReturning(
        jsonEncode({
          'data': [
            {
              'id': 1,
              'name': 'Havregryn',
              'brand': 'Axa',
              'nutrition': [
                {'code': 'energi_kcal', 'amount': 370, 'unit': 'kcal'},
              ],
            },
          ],
        }),
      );

      final results = await api.searchProducts('havre');

      expect(results, hasLength(1));
      expect(results.single.name, 'Havregryn');
      expect(results.single.nutritionPer100.kcal, 370);
    });

    test('skips the network entirely for a blank query', () async {
      var called = false;
      final api = KassalApi(
        tokenProvider: () async => 'test-token',
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      expect(await api.searchProducts('   '), isEmpty);
      expect(called, isFalse);
    });
  });

  group('productByEan', () {
    test('merges store variants and the shared declaration', () async {
      final api = _apiReturning(
        jsonEncode({
          'data': {
            'ean': '7311070363012',
            'products': [
              {
                'id': 1,
                'name': 'Havregryn',
                'current_price': 29.9,
                'store': {'name': 'Kiwi'},
              },
              {
                'id': 2,
                'name': 'Havregryn',
                'weight': 1,
                'weight_unit': 'kg',
                'current_price': 31.5,
                'store': {'name': 'Meny'},
              },
            ],
            'nutrition': [
              {'code': 'energi_kcal', 'amount': 370, 'unit': 'kcal'},
              {'code': 'protein', 'amount': 13, 'unit': 'g'},
            ],
            'allergens': [
              {'code': 'gluten', 'display_name': 'Gluten', 'contains': 'YES'},
            ],
          },
        }),
      );

      final product = await api.productByEan('7311070363012');

      expect(product, isNotNull);
      // The first listing is kept as the primary one...
      expect(product!.storeName, 'Kiwi');
      expect(product.currentPrice, 29.9);
      // ...but the weight and declaration are borrowed from elsewhere.
      expect(product.packageSize, 1000);
      expect(product.nutritionPer100.kcal, 370);
      expect(product.nutritionPer100.protein, 13);
      expect(product.allergens.single.displayName, 'Gluten');
    });

    test('returns null for an unknown barcode', () async {
      final api = _apiReturning(
        jsonEncode({'message': 'Not found'}),
        status: 404,
      );

      expect(await api.productByEan('0000000000000'), isNull);
    });

    test('returns null when the payload carries no products', () async {
      final api = _apiReturning(
        jsonEncode({
          'data': {'ean': '123', 'products': []},
        }),
      );

      expect(await api.productByEan('123'), isNull);
    });
  });

  group('error handling', () {
    test(
      'flags a missing token as an auth failure without calling out',
      () async {
        var called = false;
        final api = KassalApi(
          tokenProvider: () async => null,
          client: MockClient((_) async {
            called = true;
            return http.Response('{}', 200);
          }),
        );

        await expectLater(
          api.searchProducts('melk'),
          throwsA(
            isA<KassalException>().having(
              (e) => e.isAuthFailure,
              'auth',
              isTrue,
            ),
          ),
        );
        expect(called, isFalse);
      },
    );

    test('flags a rejected token as an auth failure', () async {
      final api = _apiReturning('{"message":"Unauthenticated"}', status: 401);

      await expectLater(
        api.searchProducts('melk'),
        throwsA(
          isA<KassalException>().having((e) => e.isAuthFailure, 'auth', isTrue),
        ),
      );
    });

    test('surfaces rate limiting distinctly', () async {
      final api = _apiReturning('{}', status: 429);

      await expectLater(
        api.searchProducts('melk'),
        throwsA(
          isA<KassalException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.message, 'message', contains('For mange')),
        ),
      );
    });

    test('reports a malformed response instead of crashing', () async {
      final api = _apiReturning('<html>oops</html>');

      await expectLater(
        api.searchProducts('melk'),
        throwsA(isA<KassalException>()),
      );
    });
  });
}
