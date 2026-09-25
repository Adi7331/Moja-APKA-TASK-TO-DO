import 'package:shared_preferences/shared_preferences.dart';

import 'cost_overview.dart';

class CostForecastPreferenceStore {
  const CostForecastPreferenceStore(this._preferences);

  static const _key = 'cost_forecast_mode';

  final SharedPreferences _preferences;

  CostForecastMode load() {
    final saved = _preferences.getString(_key);
    return CostForecastMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => CostForecastMode.allOccurrences,
    );
  }

  Future<void> save(CostForecastMode mode) async {
    await _preferences.setString(_key, mode.name);
  }
}
