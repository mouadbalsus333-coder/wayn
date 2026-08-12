import '../../models/contribution.dart';

abstract class ContributionRepository {
  Future<List<Contribution>> getContributionsByUser(String userId);

  Future<Contribution?> getContributionById(String id);

  Future<Contribution?> submitContribution(Contribution contribution);

  Future<Contribution?> updateContributionStatus(
    String contributionId,
    ContributionStatus status, {
    String? reviewedBy,
    String? reviewNote,
  });
}
