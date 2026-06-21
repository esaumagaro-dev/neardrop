/// Abstraction over the two transport modes so the transfer engine
/// doesn't care whether it's talking P2P sockets or a WebRTC relay.
abstract class TransferChannel {
  Future<void> connect();
  Future<void> sendChunk(List<int> bytes);
  Stream<List<int>> get incomingChunks;
  Future<void> close();
}
