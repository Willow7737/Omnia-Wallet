/// How this device authenticates to the Omnia node.
enum AuthMode {
  /// Mode A — on-device Ed25519 key, challenge/signature login.
  selfCustody('self'),

  /// Mode B — Supabase account (Google / GitHub / email); a node JWT is
  /// minted server-side by the `mint-node-jwt` edge function.
  supabase('supabase');

  const AuthMode(this.wire);

  /// Value persisted in secure storage.
  final String wire;

  static AuthMode fromWire(String? value) => value == AuthMode.supabase.wire
      ? AuthMode.supabase
      : AuthMode.selfCustody;
}
