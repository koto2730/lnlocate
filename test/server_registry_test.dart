import 'package:flutter_test/flutter_test.dart';
import 'package:lnlocate/localnode_server.dart';
import 'package:lnlocate/server_registry.dart';

LocalNodeServer s(String name, String host, int port, List<String> addrs) =>
    LocalNodeServer(
        name: name, port: port, hostname: host, addresses: addrs);

void main() {
  test('same name on two networks stays two entries', () {
    final r = ServerRegistry();
    r.found(const LocalNodeServer(name: 'LocalNode', port: 8080));
    r.resolved(s('LocalNode', 'a-localnode.local', 8080, ['192.168.0.5']));
    r.resolved(s('LocalNode', 'b-localnode.local', 8080, ['10.0.0.7']));

    expect(r.servers.length, 2);
    expect(r.servers.map((e) => e.addresses.first).toSet(),
        {'192.168.0.5', '10.0.0.7'});
  });

  test('same server seen on two interfaces is merged', () {
    final r = ServerRegistry();
    r.resolved(s('Office', 'm-localnode.local', 8080, ['192.168.0.5']));
    r.resolved(s('Office', 'm-localnode.local', 8080, ['10.0.0.5']));

    expect(r.servers.length, 1);
    expect(r.servers.single.addresses, ['192.168.0.5', '10.0.0.5']);
  });

  test('unresolved entry is hidden once a resolved one exists', () {
    final r = ServerRegistry();
    r.found(const LocalNodeServer(name: 'Lab', port: 8080));
    expect(r.servers.single.url, isNull);
    r.resolved(s('Lab', 'l-localnode.local', 8080, ['192.168.0.9']));
    expect(r.servers.single.url, isNotNull);
  });

  test('lost removes the server; ambiguous loss asks for a rescan', () {
    final r = ServerRegistry();
    r.resolved(s('Office', 'a.local', 8080, ['192.168.0.5']));
    expect(r.lost('Office'), isFalse);
    expect(r.servers, isEmpty);

    r.resolved(s('LocalNode', 'a.local', 8080, ['192.168.0.5']));
    r.resolved(s('LocalNode', 'b.local', 8080, ['10.0.0.7']));
    expect(r.lost('LocalNode'), isTrue);
  });
}
