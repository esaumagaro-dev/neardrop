import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/near_link_session.dart';

final nearLinkSessionProvider = Provider<NearLinkSession>((ref) {
  final session = NearLinkSession();
  ref.onDispose(() => session.disconnect());
  return session;
});

final linkStatusProvider = StateProvider<LinkStatus>((ref) => LinkStatus.disconnected);
