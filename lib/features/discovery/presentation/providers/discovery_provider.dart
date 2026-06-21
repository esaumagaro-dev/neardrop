import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/mdns_discovery_service.dart';
import '../../domain/peer.dart';

final discoveryServiceProvider = Provider<MdnsDiscoveryService>((ref) {
  final service = MdnsDiscoveryService();
  ref.onDispose(service.dispose);
  return service;
});

final discoveredPeersProvider = StreamProvider<List<Peer>>((ref) {
  final service = ref.watch(discoveryServiceProvider);
  return service.peersStream;
});

/// Kicks off advertise + browse. Call once from the dashboard on init.
final discoveryControllerProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(discoveryServiceProvider);
  final deviceName =
      '${Platform.localHostname}-${const Uuid().v4().substring(0, 4)}';
  await service.startAdvertising(
    deviceName: deviceName,
    port: 7531, // NearDrop default transfer port
    platform: Platform.operatingSystem,
  );
  await service.startBrowsing();
});
