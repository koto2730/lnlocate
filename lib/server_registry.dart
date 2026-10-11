import 'localnode_server.dart';

/// Keeps the set of servers currently visible on the LAN(s).
///
/// A device can be attached to several networks at once (Wi-Fi + Ethernet,
/// VPN, ...). The platform browsers report services from every interface but
/// without the interface, so two *different* servers may share one instance
/// name (the default name is "LocalNode"). Entries are therefore keyed by
/// `name + host + port` once resolved, and merged when the same server is seen
/// on several interfaces.
class ServerRegistry {
  // Found but not resolved yet (no host/port information).
  final Map<String, LocalNodeServer> _pending = {};
  // Resolved servers by `name|host|port`.
  final Map<String, LocalNodeServer> _resolved = {};

  /// Current servers, sorted by name then endpoint.
  List<LocalNodeServer> get servers {
    final list = [..._resolved.values];
    // Show unresolved names only while no resolved entry exists for them.
    final resolvedNames = list.map((s) => s.name).toSet();
    for (final p in _pending.values) {
      if (!resolvedNames.contains(p.name)) list.add(p);
    }
    list.sort((a, b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return c != 0 ? c : a.endpoint.compareTo(b.endpoint);
    });
    return List.unmodifiable(list);
  }

  /// A service was found (not yet resolved).
  void found(LocalNodeServer s) {
    if (_resolved.values.any((r) => r.name == s.name)) return;
    _pending[s.name] = s;
  }

  /// A service was resolved / updated. Merges addresses seen on other
  /// interfaces for the same server.
  void resolved(LocalNodeServer s) {
    _pending.remove(s.name);
    final key = _key(s);
    final existing = _resolved[key];
    if (existing == null) {
      _resolved[key] = s;
      return;
    }
    final addresses = <String>{...existing.addresses, ...s.addresses}.toList();
    _resolved[key] = s.copyWith(addresses: addresses);
  }

  /// A service disappeared. Returns true when other servers with the same
  /// name remain, i.e. the platform did not tell which one went away and the
  /// caller should rescan to rebuild the list.
  bool lost(String name) {
    _pending.remove(name);
    final matching =
        _resolved.keys.where((k) => _resolved[k]!.name == name).toList();
    for (final k in matching) {
      _resolved.remove(k);
    }
    return matching.length > 1;
  }

  void clear() {
    _pending.clear();
    _resolved.clear();
  }

  static String _key(LocalNodeServer s) =>
      '${s.name}|${(s.hostname ?? '').toLowerCase()}|${s.port}';
}
