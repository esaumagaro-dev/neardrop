import 'dart:async';
import 'package:nsd/nsd.dart';
import '../domain/peer.dart';

/// Advertises this device on the LAN and browses for other NearDrop peers
/// using mDNS/DNS-SD via the `nsd` package (works on Android, iOS, Windows,
/// macOS, Linux).
class MdnsDiscoveryService {
  static const _serviceType = '_neardrop._tcp';
  Registration? _registration;
  Discovery? _discovery;

  final _peersController = StreamController<List<Peer>>.broadcast();
  Stream<List<Peer>> get peersStream => _peersController.stream;

  final Map<String, Peer> _peers = {};

  Future<void> startAdvertising({
    required String deviceName,
    required int port,
    required String platform,
  }) async {
    _registration = await register(
      Service(
        name: deviceName,
        type: _serviceType,
        port: port,
        txt: {
          'platform': platform.codeUnits,
        },
      ),
    );
  }

  Future<void> stopAdvertising() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }

  Future<void> startBrowsing() async {
    _discovery = await startDiscovery(_serviceType);
    _discovery!.addServiceListener((service, status) {
      if (status == ServiceStatus.found && service.host != null) {
        final peer = Peer(
          id: '${service.host}:${service.port}',
          name: service.name ?? 'Unknown Device',
          ip: service.host!,
          port: service.port ?? 0,
          platform: service.txt?['platform'] != null
              ? String.fromCharCodes(service.txt!['platform']!)
              : 'unknown',
          lastSeen: DateTime.now(),
        );
        _peers[peer.id] = peer;
        _peersController.add(_peers.values.toList());
      } else if (status == ServiceStatus.lost) {
        final key = '${service.host}:${service.port}';
        _peers.remove(key);
        _peersController.add(_peers.values.toList());
      }
    });
  }

  Future<void> stopBrowsing() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }

  void dispose() {
    _peersController.close();
  }
}
