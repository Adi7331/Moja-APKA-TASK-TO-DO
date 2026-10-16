import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/business_models.dart';

void main() {
  test('product estimates margin from entered costs only', () {
    final product = BusinessProduct(
      id: 'p1',
      name: 'Lampa',
      status: BusinessProductStatus.saved,
      addedAt: DateTime.utc(2026, 10, 16),
      purchasePriceCents: 2000,
      sellingPriceCents: 10000,
      shippingCostCents: 500,
      adCostCents: 1500,
      otherCostCents: 500,
    );

    expect(product.estimatedMarginCents, 5500);
    expect(product.estimatedMarginPercent, 55);
    expect(product.qualificationScore, 0);
    expect(product.checkedCriteria, 0);
  });

  test('product with missing sale price has no estimated margin', () {
    final product = BusinessProduct(
      id: 'p1',
      name: 'Lampa',
      status: BusinessProductStatus.saved,
      addedAt: DateTime.utc(2026, 10, 16),
    );
    expect(product.estimatedMarginCents, isNull);
    expect(product.estimatedMarginPercent, isNull);
  });

  test(
    'legacy product data defaults missing checks and unknown status safely',
    () {
      final product = BusinessProduct.fromJson({
        'id': 'legacy',
        'name': 'Stary produkt',
        'status': 'future-status',
        'addedAt': '2026-10-16T10:00:00Z',
        'criteria': [true],
      });
      expect(product.status, BusinessProductStatus.saved);
      expect(product.criteria, [true, null, null, null, null]);
      expect(product.checkedCriteria, 1);
    },
  );

  test('workflow timer resumes by wall clock and reports elapsed step', () {
    final now = DateTime.utc(2026, 10, 16, 10);
    final workflow = BusinessWorkflow(
      id: 'wf',
      name: 'Film',
      steps: const [BusinessWorkflowStep(title: 'Montaż', minutes: 10)],
    );
    final session = BusinessFocusSession.start(
      id: 's1',
      workflow: workflow,
      startedAt: now,
    );
    final restored = session.copyWith(lastResumedAt: now);
    expect(
      restored.remainingAt(now.add(const Duration(minutes: 12))),
      const Duration(minutes: -2),
    );
  });
}
