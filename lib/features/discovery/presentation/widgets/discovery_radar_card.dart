import 'package:flutter/material.dart';
import 'bento_card.dart';

class DiscoveryRadarCard extends StatelessWidget {
  final int peerCount;
  const DiscoveryRadarCard({super.key, required this.peerCount});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      icon: Icons.radar_rounded,
      title: 'Nearby Devices',
      subtitle: '$peerCount device(s) found',
      child: peerCount == 0
          ? const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                height: 18,
                width: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            )
          : null,
    );
  }
}
