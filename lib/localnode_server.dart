/// A LocalNode server found on the LAN via mDNS (`_localnode._tcp`).
///
/// The announce side is documented in koto2730/localnode#308. TXT records:
/// `txtvers`, `scheme` (http|https), `path`, `name`, `auth` (pin|none),
/// `ver` and optionally `host` (certificate host name for HTTPS).
class LocalNodeServer {
  const LocalNodeServer({
    required this.name,
    required this.port,
    this.hostname,
    this.addresses = const [],
    this.attributes = const {},
  });

  /// DNS-SD instance name (what the user set as the server name).
  final String name;
  final int port;

  /// mDNS host name, e.g. `macbook-localnode.local`.
  final String? hostname;

  /// Resolved addresses (IPv4 and/or IPv6 literals).
  final List<String> addresses;

  /// TXT record key/values.
  final Map<String, String> attributes;

  /// Stable key used to de-duplicate entries while browsing.
  String get id => name;

  bool get isHttps => scheme == 'https';

  String get scheme => attributes['scheme'] == 'https' ? 'https' : 'http';

  /// `true` when the server asks for a PIN; unknown is treated as protected.
  bool get requiresPin => attributes['auth'] != 'none';

  String? get version => attributes['ver'];

  String get path {
    final p = attributes['path'];
    if (p == null || p.isEmpty) return '/';
    return p.startsWith('/') ? p : '/$p';
  }

  /// Host used to build the URL.
  ///
  /// 1. TXT `host` (HTTPS certificate host name — must be used for the
  ///    certificate to match),
  /// 2. an IPv4 address (reliable everywhere, unlike `.local` names in
  ///    mobile browsers),
  /// 3. any other address, then the mDNS host name.
  String? get host {
    final txtHost = attributes['host'];
    if (txtHost != null && txtHost.isNotEmpty) return txtHost;
    for (final a in addresses) {
      if (_isIpv4(a)) return a;
    }
    if (addresses.isNotEmpty) return addresses.first;
    final h = hostname;
    if (h != null && h.isNotEmpty) return h.endsWith('.') ? h.substring(0, h.length - 1) : h;
    return null;
  }

  /// URL to open in the browser, or null if the host is not known yet.
  Uri? get url {
    final h = host;
    if (h == null) return null;
    return Uri(
      scheme: scheme,
      host: _stripScope(h),
      port: port,
      path: path,
    );
  }

  /// Human readable `host:port` for the list.
  String get endpoint {
    final h = host;
    if (h == null) return ':$port';
    return h.contains(':') && !h.startsWith('[') ? '[$h]:$port' : '$h:$port';
  }

  LocalNodeServer copyWith({
    String? hostname,
    List<String>? addresses,
    int? port,
    Map<String, String>? attributes,
  }) =>
      LocalNodeServer(
        name: name,
        port: port ?? this.port,
        hostname: hostname ?? this.hostname,
        addresses: addresses ?? this.addresses,
        attributes: attributes ?? this.attributes,
      );

  static bool _isIpv4(String s) =>
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(s);

  // `fe80::1%en0` -> `fe80::1` (zone ids are not valid in URLs).
  static String _stripScope(String h) {
    final i = h.indexOf('%');
    return i < 0 ? h : h.substring(0, i);
  }
}
