abstract class GateRepository {
  Future<String> publicKey();

  Future<String> scan(String qr);
}
