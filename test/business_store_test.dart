import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dzien_po_dniu/business_models.dart';
import 'package:dzien_po_dniu/business_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local product write survives reopening and deletion remains queued',
    () async {
      SharedPreferences.setMockInitialValues({});
      var preferences = await SharedPreferences.getInstance();
      var store = BusinessStore(preferences, 'user-1');
      final product = BusinessProduct(
        id: 'p1',
        name: 'Lampa',
        status: BusinessProductStatus.saved,
        addedAt: DateTime.utc(2026, 10, 16),
      );
      await store.saveProduct(product);
      store.dispose();
      store = BusinessStore(preferences, 'user-1');
      expect(store.snapshot.products.single.name, 'Lampa');
      await store.remove('product', 'p1');
      await store.mergeRemote([
        {
          'id': 'p1',
          'kind': 'product',
          'payload': product.toJson(),
          'deleted_at': null,
        },
      ]);
      expect(store.snapshot.products, isEmpty);
      expect(store.snapshot.pending.single['deleted'], isTrue);
      store.dispose();
    },
  );

  test('preset Focus workflows are present and preserve step durations', () {
    expect(businessPresetWorkflows, hasLength(3));
    expect(businessPresetWorkflows.first.totalMinutes, 40);
  });

  test(
    'concurrent local writes keep each record and owner data isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = BusinessStore(preferences, 'user-a');
      final second = BusinessStore(preferences, 'user-b');
      BusinessProduct product(String id) => BusinessProduct(
        id: id,
        name: id,
        status: BusinessProductStatus.saved,
        addedAt: DateTime.utc(2026, 10, 16),
      );

      await Future.wait([
        first.saveProduct(product('one')),
        first.saveProduct(product('two')),
      ]);
      expect(first.snapshot.products.map((item) => item.id).toSet(), {
        'one',
        'two',
      });
      expect(first.snapshot.pending, hasLength(2));
      expect(second.snapshot.products, isEmpty);
      first.dispose();
      second.dispose();
    },
  );
}
