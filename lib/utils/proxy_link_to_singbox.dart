import 'dart:convert';

import 'package:loggy/loggy.dart';

final _loggy = Loggy('ProfileConfig');

bool _isProxyLinkLine(String line) {
  final t = line.trim();
  if (t.isEmpty) return false;
  final uri = Uri.tryParse(t);
  if (uri == null || !uri.hasScheme) return false;
  const schemes = {
    'vless', 'vmess', 'trojan', 'ss', 'tuic', 'hy2', 'hysteria2',
    'hy', 'hysteria', 'wg', 'warp',
  };
  return schemes.contains(uri.scheme.toLowerCase());
}

Map<String, dynamic>? _vlessToOutbound(Uri uri) {
  if (uri.scheme.toLowerCase() != 'vless') return null;
  final userInfo = uri.userInfo;
  if (userInfo.isEmpty) return null;
  final uuid = userInfo;
  final server = uri.host;
  final port = uri.hasPort ? uri.port : 443;
  final q = uri.queryParameters;
  final tag = uri.hasFragment
      ? Uri.decodeComponent(uri.fragment.split('&&')[0])
      : 'proxy';
  final network = q['type'] ?? 'tcp';
  final flow = q['flow'];
  final sni = q['sni'] ?? q['host'] ?? '';
  final security = (q['security'] ?? '').toLowerCase();
  final outbound = <String, dynamic>{
    'type': 'vless',
    'tag': tag.isNotEmpty ? tag : 'proxy',
    'server': server,
    'server_port': port,
    'uuid': uuid,
    'network': network,
  };
  if (flow != null && flow.isNotEmpty) outbound['flow'] = flow;
  if (security == 'reality') {
    final pbk = q['pbk'];
    final sid = q['sid'] ?? '';
    final fp = q['fp'] ?? 'chrome';
    if (pbk != null && pbk.isNotEmpty) {
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni.isNotEmpty ? sni : 'www.google.com',
        'utls': {'enabled': true, 'fingerprint': fp},
        'reality': {
          'enabled': true,
          'public_key': pbk,
          'short_id': sid,
        },
      };
    }
  } else if (security == 'tls' || sni.isNotEmpty) {
    outbound['tls'] = {
      'enabled': true,
      'server_name': sni.isNotEmpty ? sni : server,
    };
  }
  return outbound;
}

Map<String, dynamic>? _lineToOutbound(String line) {
  final uri = Uri.tryParse(line.trim());
  if (uri == null) return null;
  return _vlessToOutbound(uri);
}

String? proxyLinksToSingboxJson(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('{')) return null;
  _loggy.debug('[proxyLinksToSingboxJson] input: ${content.length} chars, lines: ${trimmed.split('\n').length}');
  final lines = trimmed.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
  final outbounds = <Map<String, dynamic>>[];
  var hasProxyLink = false;
  for (final line in lines) {
    if (_isProxyLinkLine(line)) {
      hasProxyLink = true;
      final ob = _lineToOutbound(line);
      if (ob != null) outbounds.add(ob);
    }
  }
  if (!hasProxyLink || outbounds.isEmpty) {
    _loggy.debug('[proxyLinksToSingboxJson] result: null (no proxy links or empty)');
    return null;
  }
  final json = jsonEncode({'outbounds': outbounds});
  _loggy.debug('[proxyLinksToSingboxJson] result: ${outbounds.length} outbounds');
  return json;
}

void _ensureRealityUtls(Map<String, dynamic> data) {
  final outbounds = data['outbounds'];
  if (outbounds is! List) return;
  for (final ob in outbounds) {
    if (ob is! Map<String, dynamic>) continue;
    if (ob['type'] != 'vless') continue;
    final tls = ob['tls'];
    if (tls is! Map<String, dynamic> || tls['reality'] is! Map) continue;
    if (tls['utls'] is Map) continue;
    tls['utls'] = <String, dynamic>{'enabled': true, 'fingerprint': 'chrome'};
    _loggy.debug('[normalizeSingboxConfig] added utls to reality outbound ${ob['tag']}');
  }
}

String normalizeSingboxConfig(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('{')) return content;
  try {
    final data = jsonDecode(trimmed);
    if (data is! Map) return content;
    _ensureRealityUtls(data as Map<String, dynamic>);
    final inbounds = data['inbounds'];
    if (inbounds is List) {
      var addressToListenCount = 0;
      for (final item in inbounds) {
        if (item is Map) {
          if (item.containsKey('address')) {
            item['listen'] = item['address'];
            item.remove('address');
            addressToListenCount++;
          }
          item.remove('route_exclude_address');
        }
      }
      if (addressToListenCount > 0) {
        _loggy.debug('[normalizeSingboxConfig] inbounds: ${inbounds.length}, address->listen: $addressToListenCount');
      }
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    return content;
  }
}
