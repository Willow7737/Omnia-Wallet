import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/models.dart';

void main() {
  test('NodeInfo parses the public node/info schema', () {
    final n = NodeInfo.fromJson({
      'node_id': 'abcd',
      'version': '0.1.81',
      'protocol_version': 3,
      'uptime_seconds': 3725,
      'peers': 4,
      'finalized_height': 1200,
      'shard_count': 6,
    });
    expect(n.version, '0.1.81');
    expect(n.protocolVersion, '3');
    expect(n.peers, 4);
    expect(n.finalizedHeight, 1200);
    expect(n.shardCount, 6);
    expect(n.uptimeSeconds, 3725);
  });

  test('NodeInfo tolerates missing fields', () {
    final n = NodeInfo.fromJson({});
    expect(n.version, '—');
    expect(n.peers, 0);
  });
}
