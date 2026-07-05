import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/governance.dart';
import '../data/governance_repository.dart';
import 'providers.dart';

final governanceRepositoryProvider = Provider<GovernanceRepository>((ref) {
  return GovernanceRepository(
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(apiClientProvider),
  );
});

/// The list of governance proposals. Auto-refreshes when invalidated
/// (e.g. after casting a vote or creating a proposal).
final proposalsProvider = FutureProvider<List<Proposal>>((ref) async {
  return ref.watch(governanceRepositoryProvider).proposals();
});
