// Real mDNS discovery against a running LocalNode (#308).
//
//   localnode-cli --mdns --name "Office LocalNode" ...
//   flutter test integration_test -d macos \
//     --dart-define=EXPECT_SERVER="Office LocalNode"
//
// Skipped when EXPECT_SERVER is not given.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lnlocate/localnode_server.dart';
import 'package:lnlocate/server_discovery.dart';

const _expected = String.fromEnvironment('EXPECT_SERVER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('finds a LocalNode announced via mDNS', (tester) async {
    final discovery = BonsoirServerDiscovery();
    addTearDown(discovery.dispose);

    LocalNodeServer? found;
    final sub = discovery.servers.listen((list) {
      for (final s in list) {
        if (s.name == _expected && s.url != null) found = s;
      }
    });
    addTearDown(sub.cancel);

    await discovery.start();
    for (var i = 0; i < 30 && found == null; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)));
    }

    expect(found, isNotNull, reason: 'server "$_expected" was not discovered');
    // ignore: avoid_print
    print('FOUND ${found!.name} -> ${found!.url} '
        '(https=${found!.isHttps}, pin=${found!.requiresPin}, '
        'ver=${found!.version}, txt=${found!.attributes})');
    expect(found!.url!.port, isNonZero);
  }, skip: _expected.isEmpty);
}
