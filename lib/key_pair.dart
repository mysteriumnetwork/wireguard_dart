class KeyPair {
  final String publicKey;
  final String privateKey;

  KeyPair(this.publicKey, this.privateKey);

  @override
  String toString() {
    return 'KeyPair{publicKey: $publicKey, privateKey: $privateKey}';
  }
}
