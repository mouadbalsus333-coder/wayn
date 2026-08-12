import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user.dart' as app_user;
import 'user_repository.dart';

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<app_user.User?> createOrUpdateUser(app_user.User user) async {
    final response = await _supabase
        .from('users')
        .upsert(user.toMap(), onConflict: 'id')
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return app_user.User.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<app_user.User?> getCurrentUser() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    return getUserById(authUser.id);
  }

  @override
  Future<app_user.User?> getUserById(String id) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return app_user.User.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<app_user.User>> searchUsers(String query) async {
    final search = query.trim();
    if (search.isEmpty) {
      return [];
    }

    final response = await _supabase
        .from('users')
        .select()
        .or(
          'email.ilike.%$search%,username.ilike.%$search%,display_name.ilike.%$search%',
        );

    return (response as List)
        .map((item) => app_user.User.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
