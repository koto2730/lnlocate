import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lnlocate/localnode_server.dart';
import 'package:lnlocate/main.dart';
import 'package:lnlocate/server_discovery.dart';

class FakeDiscovery implements ServerDiscovery {
  final _servers = StreamController<List<LocalNodeServer>>.broadcast();
  final _errors = StreamController<String>.broadcast();
  int startCount = 0;

  @override
  Stream<List<LocalNodeServer>> get servers => _servers.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Future<void> start() async => startCount++;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}

  void emit(List<LocalNodeServer> list) => _servers.add(list);
}

void main() {
  testWidgets('shows searching state, then lists servers and opens URL',
      (tester) async {
    final discovery = FakeDiscovery();
    final opened = <Uri>[];

    await tester.pumpWidget(MaterialApp(
      home: ServerListPage(
        discovery: discovery,
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      ),
    ));
    expect(find.text('LocalNode を検索中…'), findsOneWidget);
    expect(discovery.startCount, 1);

    discovery.emit(const [
      LocalNodeServer(
        name: 'Office',
        port: 8080,
        addresses: ['192.168.0.10'],
        attributes: {'scheme': 'http', 'path': '/', 'auth': 'pin'},
      ),
      LocalNodeServer(
        name: 'Lab',
        port: 8443,
        addresses: ['192.168.0.20'],
        attributes: {'scheme': 'https', 'auth': 'none'},
      ),
    ]);
    await tester.pump();

    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
    // A list is always shown first; nothing is opened automatically.
    expect(opened, isEmpty);

    await tester.tap(find.text('Lab'));
    await tester.pump();
    expect(opened.single.toString(), 'https://192.168.0.20:8443/');
  });

  testWidgets('re-scan button restarts discovery', (tester) async {
    final discovery = FakeDiscovery();
    await tester.pumpWidget(MaterialApp(
      home: ServerListPage(discovery: discovery, openUrl: (_) async => true),
    ));
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    expect(discovery.startCount, 2);
  });

  test('LNLocateApp builds with a discovery', () {
    expect(LNLocateApp(discovery: FakeDiscovery()), isA<Widget>());
  });
}
