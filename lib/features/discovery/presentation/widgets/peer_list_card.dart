import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/peer.dart';
import 'bento_card.dart';

class PeerListCard extends StatelessWidget {
  final AsyncValue<List<Peer>> peersAsync;
  const PeerListCard({super.key, required this.peersAsync});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      icon: Icons.devices_rounded,
      title: 'Send a File',
      subtitle: 'Tap a device to share',
      child: peersAsync.when(
        data: (peers) => peers.isEmpty
            ? const Text('Searching...',
                style: TextStyle(color: Colors.white60, fontSize: 12))
            : Column(
                children: peers
                    .take(2)
                    .map((p) => Text(
                          '• ${p.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ))
                    .toList(),
              ),
        loading: () => const Text('Searching...',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        error: (_, __) => const Text('Discovery error',
            style: TextStyle(color: Colors.redAccent, fontSize: 12)),
      ),
    );
  }
}
