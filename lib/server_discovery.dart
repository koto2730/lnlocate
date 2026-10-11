import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'localnode_server.dart';

/// Finds LocalNode servers on the LAN.
abstract class ServerDiscovery {
  /// Current list of servers; emits on every change.
  Stream<List<LocalNodeServer>> get servers;

  /// Error text of the last failure, if any.
  Stream<String> get errors;

  /// Starts browsing. Safe to call repeatedly (restarts the scan).
  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}

/// [ServerDiscovery] backed by Bonsoir (Bonjour / NSD / Avahi / Windows DNS-SD).
class BonsoirServerDiscovery implements ServerDiscovery {
  static const String serviceType = '_localnode._tcp';

  final _serversController =
      StreamController<List<LocalNodeServer>>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  final Map<String, LocalNodeServer> _found = {};

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  @override
  Stream<List<LocalNodeServer>> get servers => _serversController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> start() async {
    await stop();
    _found.clear();
    _emit();

    final discovery = BonsoirDiscovery(type: serviceType);
    _discovery = discovery;
    try {
      await discovery.initialize();
      _sub = discovery.eventStream?.listen(
        (event) => _onEvent(discovery, event),
        onError: (Object e) => _errorsController.add('$e'),
      );
      await discovery.start();
    } catch (e) {
      _errorsController.add('$e');
    }
  }

  void _onEvent(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        _upsert(event.service);
        // Addresses / TXT are only known after resolving.
        event.service.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent():
      case BonsoirDiscoveryServiceUpdatedEvent():
        _upsert(event.service!);
      case BonsoirDiscoveryServiceLostEvent():
        _found.remove(event.service.name);
        _emit();
      default:
        break;
    }
  }

  void _upsert(BonsoirService s) {
    _found[s.name] = LocalNodeServer(
      name: s.name,
      port: s.port,
      hostname: s.hostname,
      addresses: s.hostAddresses,
      attributes: s.attributes,
    );
    _emit();
  }

  void _emit() {
    if (_serversController.isClosed) return;
    final list = _found.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _serversController.add(List.unmodifiable(list));
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    final d = _discovery;
    _discovery = null;
    try {
      await d?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _serversController.close();
    await _errorsController.close();
  }
}
