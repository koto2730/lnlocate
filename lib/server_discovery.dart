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

  /// Asks the platform to resolve [server] again (host, port, TXT).
  Future<void> retryResolve(LocalNodeServer server);

  Future<void> stop();

  Future<void> dispose();
}

/// [ServerDiscovery] backed by Bonsoir (Bonjour / NSD / Avahi / Windows DNS-SD).
class BonsoirServerDiscovery implements ServerDiscovery {
  static const String serviceType = '_localnode._tcp';

  /// Resolving needs a round trip to the server; a lost packet or a busy
  /// responder makes it fail once, so try a few times before giving up.
  static const int maxResolveAttempts = 4;
  static const Duration resolveRetryInterval = Duration(seconds: 3);

  final _serversController =
      StreamController<List<LocalNodeServer>>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  final ServerRegistry _registry = ServerRegistry();

  // Found but not resolved yet, and how many times resolving was requested.
  final Map<String, BonsoirService> _unresolved = {};
  final Map<String, int> _attempts = {};

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;
  Timer? _rescanTimer;
  Timer? _retryTimer;

  @override
  Stream<List<LocalNodeServer>> get servers => _serversController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> start() async {
    await stop();
    _registry.clear();
    _unresolved.clear();
    _attempts.clear();
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
      _retryTimer = Timer.periodic(resolveRetryInterval, (_) => _retryTick());
    } catch (e) {
      _errorsController.add('$e');
    }
  }

  void _onEvent(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        final s = event.service;
        _registry.found(_toServer(s));
        _unresolved[s.name] = s;
        _attempts[s.name] = 1;
        _emit();
        // Addresses / TXT are only known after resolving.
        _resolve(s);
      case BonsoirDiscoveryServiceResolvedEvent():
        _markResolved(event.service);
      case BonsoirDiscoveryServiceUpdatedEvent():
        _markResolved(event.service);
      case BonsoirDiscoveryServiceLostEvent():
        _unresolved.remove(event.service.name);
        _attempts.remove(event.service.name);
        final ambiguous = _registry.lost(event.service.name);
        _emit();
        // Same name on several networks: we cannot tell which one left.
        if (ambiguous) _scheduleRescan();
      default:
        break;
    }
  }

  void _markResolved(BonsoirService s) {
    _unresolved.remove(s.name);
    _attempts.remove(s.name);
    _registry.resolved(_toServer(s));
    _emit();
  }

  void _resolve(BonsoirService s) {
    final d = _discovery;
    if (d == null) return;
    try {
      s.resolve(d.serviceResolver);
    } catch (e) {
      _errorsController.add('$e');
    }
  }

  void _retryTick() {
    var changed = false;
    for (final entry in _unresolved.entries.toList()) {
      final name = entry.key;
      final attempts = _attempts[name] ?? 0;
      if (attempts >= maxResolveAttempts) {
        // Give up for now; the row says so and a tap tries again.
        _registry.found(_toServer(entry.value, resolveFailed: true));
        changed = true;
        continue;
      }
      _attempts[name] = attempts + 1;
      _resolve(entry.value);
    }
    if (changed) _emit();
  }

  @override
  Future<void> retryResolve(LocalNodeServer server) async {
    final s = _unresolved[server.name];
    if (s == null) return;
    _attempts[server.name] = 1;
    _registry.found(_toServer(s));
    _emit();
    _resolve(s);
  }

  LocalNodeServer _toServer(BonsoirService s, {bool resolveFailed = false}) =>
      LocalNodeServer(
        name: s.name,
        port: s.port,
        hostname: s.hostname,
        addresses: s.hostAddresses,
        attributes: s.attributes,
        resolveFailed: resolveFailed,
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
    _retryTimer?.cancel();
    _retryTimer = null;
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
