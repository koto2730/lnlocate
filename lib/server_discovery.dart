import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'localnode_server.dart';
import 'server_registry.dart';

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
  final ServerRegistry _registry = ServerRegistry();
  Timer? _rescanTimer;

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  @override
  Stream<List<LocalNodeServer>> get servers => _serversController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> start() async {
    await stop();
    _registry.clear();
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
        _registry.found(_toServer(event.service));
        _emit();
        // Addresses / TXT are only known after resolving.
        event.service.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent():
        _registry.resolved(_toServer(event.service));
        _emit();
      case BonsoirDiscoveryServiceUpdatedEvent():
        _registry.resolved(_toServer(event.service));
        _emit();
      case BonsoirDiscoveryServiceLostEvent():
        final ambiguous = _registry.lost(event.service.name);
        _emit();
        // Same name on several networks: we cannot tell which one left.
        if (ambiguous) _scheduleRescan();
      default:
        break;
    }
  }

  LocalNodeServer _toServer(BonsoirService s) => LocalNodeServer(
        name: s.name,
        port: s.port,
        hostname: s.hostname,
        addresses: s.hostAddresses,
        attributes: s.attributes,
      );

  void _scheduleRescan() {
    _rescanTimer?.cancel();
    _rescanTimer = Timer(const Duration(seconds: 1), () {
      if (!_serversController.isClosed) start();
    });
  }

  void _emit() {
    if (_serversController.isClosed) return;
    _serversController.add(_registry.servers);
  }

  @override
  Future<void> stop() async {
    _rescanTimer?.cancel();
    _rescanTimer = null;
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
