import 'package:flutter_test/flutter_test.dart';
import 'package:lnlocate/localnode_server.dart';

void main() {
  group('LocalNodeServer.url', () {
    test('prefers IPv4 over the .local host name', () {
      const s = LocalNodeServer(
        name: 'n',
        port: 8080,
        hostname: 'mac-localnode.local',
        addresses: ['fe80::1%en0', '192.168.0.5'],
        attributes: {'scheme': 'http', 'path': '/'},
      );
      expect(s.url.toString(), 'http://192.168.0.5:8080/');
    });

    test('uses TXT host for HTTPS certificate names', () {
      const s = LocalNodeServer(
        name: 'n',
        port: 8443,
        addresses: ['192.168.0.5'],
        attributes: {'scheme': 'https', 'host': 'node.example.com'},
      );
      expect(s.url.toString(), 'https://node.example.com:8443/');
    });

    test('falls back to host name and defaults', () {
      const s = LocalNodeServer(
        name: 'n',
        port: 80,
        hostname: 'box-localnode.local.',
      );
      expect(s.url.toString(), 'http://box-localnode.local/');
      expect(s.requiresPin, isTrue); // unknown auth is treated as protected
    });

    test('brackets IPv6 and strips zone id', () {
      const s = LocalNodeServer(
        name: 'n',
        port: 8080,
        addresses: ['fe80::1%en0'],
      );
      expect(s.url.toString(), 'http://[fe80::1]:8080/');
      expect(s.endpoint, '[fe80::1%en0]:8080');
    });

    test('url is null until the host is known', () {
      const s = LocalNodeServer(name: 'n', port: 8080);
      expect(s.url, isNull);
    });

    test('normalises path', () {
      const s = LocalNodeServer(
        name: 'n',
        port: 8080,
        addresses: ['10.0.0.1'],
        attributes: {'path': 'app'},
      );
      expect(s.url.toString(), 'http://10.0.0.1:8080/app');
    });
  });
}
