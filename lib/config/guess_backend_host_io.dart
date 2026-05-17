import 'dart:io';

/// When phone and PC share a USB / hotspot tether, the gateway is usually the PC (`.1`).
Future<String?> guessBackendHostFromInterfaces() async {
  try {
    final ifaces = await NetworkInterface.list();
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        if (addr.type != InternetAddressType.IPv4) continue;
        final s = addr.address;
        if (s.startsWith('127.') || s.startsWith('169.254.')) continue;
        if (s.startsWith('192.168.137.')) return '192.168.137.1';
        if (s.startsWith('172.20.10.')) return '172.20.10.1';
      }
    }
  } catch (_) {}
  return null;
}
