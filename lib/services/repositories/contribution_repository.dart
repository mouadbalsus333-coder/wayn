import '../../models/contribution.dart';

abstract class ContributionRepository {
  /// Get the current user's contributions.
  Future<List<Contribution>> getContributionsByUser(
    String userId, {
    ContributionStatus? status,
    int offset = 0,
    int limit = 20,
  });

  /// Get one contribution owned by the current user.
  Future<Contribution?> getContributionById(
    String id,
  );

  /// Submit a new contribution.
  Future<Contribution?> submitContribution(
    Contribution contribution,
  );

  /// Cancel a pending contribution owned by the current user.
  Future<Contribution?> cancelContribution(
    String contributionId,
  );
}