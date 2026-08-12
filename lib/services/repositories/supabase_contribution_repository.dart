import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/contribution.dart';
import 'contribution_repository.dart';

class SupabaseContributionRepository implements ContributionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Contribution?> getContributionById(String id) async {
    final response = await _supabase
        .from('contributions')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Contribution.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<Contribution>> getContributionsByUser(String userId) async {
    final response = await _supabase
        .from('contributions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Contribution.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<Contribution?> submitContribution(Contribution contribution) async {
    final response = await _supabase
        .from('contributions')
        .insert(contribution.toMap())
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Contribution.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<Contribution?> updateContributionStatus(
    String contributionId,
    ContributionStatus status, {
    String? reviewedBy,
    String? reviewNote,
  }) async {
    final response = await _supabase
        .from('contributions')
        .update({
          'status': status.name,
          'reviewed_by': reviewedBy,
          'review_note': reviewNote,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', contributionId)
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Contribution.fromMap(Map<String, dynamic>.from(response));
  }
}
