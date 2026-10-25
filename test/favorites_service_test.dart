import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('FavoritesService can add, remove, and query favorites', () async {
    final service = FavoritesService.instance;
    await service.init();

    expect(service.isFavorite('media_1'), isFalse);
    expect(service.count, 0);

    final added = await service.toggleFavorite('media_1');
    expect(added, isTrue);
    expect(service.isFavorite('media_1'), isTrue);
    expect(service.count, 1);

    final removed = await service.toggleFavorite('media_1');
    expect(removed, isFalse);
    expect(service.isFavorite('media_1'), isFalse);
    expect(service.count, 0);
  });
}
