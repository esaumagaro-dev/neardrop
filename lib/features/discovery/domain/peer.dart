class Peer {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform; // android, ios, windows, macos, linux
  final DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    required this.lastSeen,
  });

  Peer copyWith({DateTime? lastSeen}) => Peer(
        id: id,
        name: name,
        ip: ip,
        port: port,
        platform: platform,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
