import '../models/contribution.dart';
import 'repositories/contribution_repository.dart';
import 'repositories/repository_factory.dart';

class ContributionService {
  final ContributionRepository _contributionRepository;

  ContributionService({ContributionRepository? contributionRepository})
    : _contributionRepository =
          contributionRepository ?? createContributionRepository();

  Future<List<Contribution>> getContributionsByUser(String userId) async {
    return _contributionRepository.getContributionsByUser(userId);
  }

  Future<Contribution?> getContributionById(String id) async {
    return _contributionRepository.getContributionById(id);
  }

  Future<Contribution?> submitContribution(Contribution contribution) async {
    return _contributionRepository.submitContribution(contribution);
  }

  Future<Contribution?> updateContributionStatus(
    String contributionId,
    ContributionStatus status, {
    String? reviewedBy,
    String? reviewNote,
  }) async {
    return _contributionRepository.updateContributionStatus(
      contributionId,
      status,
      reviewedBy: reviewedBy,
      reviewNote: reviewNote,
    );
  }
}
