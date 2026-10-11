import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'localnode_server.dart';
import 'server_discovery.dart';

void main() {
  runApp(LNLocateApp(discovery: BonsoirServerDiscovery()));
}

class LNLocateApp extends StatelessWidget {
  const LNLocateApp({super.key, required this.discovery});

  final ServerDiscovery discovery;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LNLocate',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ServerListPage(discovery: discovery),
    );
  }
}

class ServerListPage extends StatefulWidget {
  const ServerListPage({
    super.key,
    required this.discovery,
    this.openUrl = _defaultOpenUrl,
  });

  final ServerDiscovery discovery;

  /// Opens [url] in the default browser. Injectable for tests.
  final Future<bool> Function(Uri url) openUrl;

  static Future<bool> _defaultOpenUrl(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  StreamSubscription<String>? _errorSub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _errorSub = widget.discovery.errors.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _scan();
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    widget.discovery.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _error = null);
    await widget.discovery.start();
  }

  Future<void> _open(LocalNodeServer server) async {
    final url = server.url;
    final messenger = ScaffoldMessenger.of(context);
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('アドレスを解決中です。少し待ってからもう一度お試しください。')),
      );
      return;
    }
    final ok = await widget.openUrl(url);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('ブラウザで開けませんでした: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LNLocate'),
        actions: [
          IconButton(
            tooltip: '再検索',
            icon: const Icon(Icons.refresh),
            onPressed: _scan,
          ),
        ],
      ),
      body: StreamBuilder<List<LocalNodeServer>>(
        stream: widget.discovery.servers,
        initialData: const [],
        builder: (context, snapshot) {
          final servers = snapshot.data ?? const [];
          if (_error != null && servers.isEmpty) {
            return _Message(
              icon: Icons.error_outline,
              title: '検索できませんでした',
              detail: _error!,
              onRetry: _scan,
            );
          }
          if (servers.isEmpty) {
            return _Message(
              icon: Icons.wifi_find,
              title: 'LocalNode を検索中…',
              detail: '同じネットワーク内で mDNS を有効にした LocalNode が見つかるとここに表示されます。',
              busy: true,
              onRetry: _scan,
            );
          }
          return ListView.separated(
            itemCount: servers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = servers[i];
              return ListTile(
                leading: Icon(s.isHttps ? Icons.lock_outline : Icons.dns_outlined),
                title: Text(s.name),
                subtitle: Text(
                  '${s.scheme}://${s.endpoint}${s.requiresPin ? '  ・  PIN あり' : ''}',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(s),
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onRetry,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                  width: 32, height: 32, child: CircularProgressIndicator())
            else
              Icon(icon, size: 40),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再検索'),
            ),
          ],
        ),
      ),
    );
  }
}
