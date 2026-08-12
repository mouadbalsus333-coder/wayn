import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/task.dart';
import 'task_repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Task?> createTask(Task task) async {
    final response = await _supabase
        .from('tasks')
        .insert(task.toMap())
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Task.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<Task?> getTaskById(String taskId) async {
    final response = await _supabase
        .from('tasks')
        .select()
        .eq('id', taskId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Task.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<Task>> getActiveTasks({int limit = 20}) async {
    final response = await _supabase
        .from('tasks')
        .select()
        .eq('status', TaskStatus.active.name)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => Task.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<Task?> updateTaskStatus(String taskId, TaskStatus status) async {
    final response = await _supabase
        .from('tasks')
        .update({'status': status.name})
        .eq('id', taskId)
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Task.fromMap(Map<String, dynamic>.from(response));
  }
}
