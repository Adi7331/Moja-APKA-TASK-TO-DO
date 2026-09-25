import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/cost_forecast_preferences.dart';
import 'package:dzien_po_dniu/cost_overview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'defaults to all occurrences and persists the selected mode locally',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = CostForecastPreferenceStore(preferences);

      expect(store.load(), CostForecastMode.allOccurrences);
      await store.save(CostForecastMode.nextOnly);

      expect(store.load(), CostForecastMode.nextOnly);
    },
  );

  test('falls back to all occurrences for an unknown stored value', () async {
    SharedPreferences.setMockInitialValues({'cost_forecast_mode': 'unknown'});
    final preferences = await SharedPreferences.getInstance();

    expect(
      CostForecastPreferenceStore(preferences).load(),
      CostForecastMode.allOccurrences,
    );
  });
}
