import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../link/presentation/screens/pairing_screen.dart';
import '../../../transfer/presentation/screens/transfer_history_screen.dart';
import '../providers/discovery_provider.dart';
import '../widgets/bento_card.dart';
import '../widgets/peer_list_card.dart';
import '../widgets/discovery_radar_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _permissionsGranted = false;
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();
    final allGranted = statuses.values.every((s) => s.isGranted);

    if (allGranted && mounted) {
      setState(() {
        _permissionsGranted = true;
        _permissionsChecked = true;
      });
      ref.read(discoveryControllerProvider);
    } else if (mounted) {
      setState(() => _permissionsChecked = true);
      final denied = statuses.entries
          .where((e) => !e.value.isGranted)
          .map((e) => e.key.toString())
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permissions denied: $denied'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final peersAsync = ref.watch(discoveredPeersProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NearDrop',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fast, secure, cross-platform sharing',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95,
                    children: [
                      DiscoveryRadarCard(
                        peerCount: peersAsync.maybeWhen(
                          data: (peers) => peers.length,
                          orElse: () => 0,
                        ),
                      ),
                      BentoCard(
                        icon: Icons.link_rounded,
                        title: 'NearLink',
                        subtitle: 'Clipboard & notifications',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PairingScreen()),
                        ),
                      ),
                      PeerListCard(peersAsync: peersAsync),
                      BentoCard(
                        icon: Icons.history_rounded,
                        title: 'History',
                        subtitle: 'Recent transfers',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TransferHistoryScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
