import '../models/contribution.dart';
import 'repositories/contribution_repository.dart';
import 'repositories/repository_factory.dart';

class ContributionService {
  final ContributionRepository _contributionRepository;

  ContributionService({
    ContributionRepository? contributionRepository,
  }) : _contributionRepository =
          contributionRepository ?? createContributionRepository();

  // ============================================================
  // Get current user's contributions
  // ============================================================

  Future<List<Contribution>> getContributionsByUser(
    String userId, {
    ContributionStatus? status,
    int offset = 0,
    int limit = 20,
  }) async {
    return _contributionRepository.getContributionsByUser(
      userId,
      status: status,
      offset: offset,
      limit: limit,
    );
  }

  // ============================================================
  // Get one contribution
  // ============================================================

  Future<Contribution?> getContributionById(
    String id,
  ) async {
    return _contributionRepository.getContributionById(
      id,
    );
  }

  // ============================================================
  // Submit contribution
  // ============================================================

  Future<Contribution?> submitContribution(
    Contribution contribution,
  ) async {
    return _contributionRepository.submitContribution(
      contribution,
    );
  }

  // ============================================================
  // Cancel pending contribution
  // ============================================================

  Future<Contribution?> cancelContribution(
    String contributionId,
  ) async {
    return _contributionRepository.cancelContribution(
      contributionId,
    );
  }
}