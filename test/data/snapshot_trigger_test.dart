import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('writeAutoSnapshot completes without throwing', () async {
    final app = AppState();
    // In the test host there is no path_provider dir; the snapshot write must
    // fail silently and never throw.
    await app.writeAutoSnapshot();
  });
}
