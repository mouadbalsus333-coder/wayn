import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/task.dart';
import 'task_repository.dart';

class FastApiTaskRepository implements TaskRepository {
  final DartHttpApiClient _api;

  FastApiTaskRepository(this._api);

  @override
  Future<List<Task>> getActiveTasks({int limit = 20}) async {
    try {
      // The backend returns the list of active point tasks (RewardTaskRead).
      // The `limit` query is intentionally not sent: the backend /tasks
      // endpoint returns every active rule and clients filter as needed.
      final response = await _api.get(
        '/api/v1/points/tasks',
      );

      return _tasksFromResponse(response);
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // The remaining TaskRepository methods belong to admin/other flows that
  // are not exposed on the end-user FastAPI surface, so they are not wired.

  @override
  Future<Task?> getTaskById(String taskId) async {
    return null;
  }

  @override
  Future<Task?> createTask(Task task) async {
    throw UnsupportedError(
      'Point tasks can only be created by admins.',
    );
  }

  @override
  Future<Task?> updateTaskStatus(String taskId, TaskStatus status) async {
    throw UnsupportedError(
      'Point task status can only be changed by admins.',
    );
  }

  // ================================================================
  // Response parsing
  //
  // The backend RewardTaskRead payload differs from Task.fromMap's
  // expectations, so each reward task is mapped explicitly:
  //   * `reward_points`          -> rewardPoints
  //   * `requires_approval`      -> requiresReview
  //   * `key` (action key)       -> metadata['action_key']
  // ================================================================

  List<Task> _tasksFromResponse(dynamic response) {
    if (response == null) {
      return [];
    }

    final items = response is List
        ? response
        : (response is Map ? response['items'] : null);

    if (items is! List) {
      return [];
    }

    final tasks = <Task>[];

    for (final item in items) {
      if (item is! Map) {
        continue;
      }

      try {
        tasks.add(
          _taskFromMap(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        // Skip malformed task objects instead of failing the whole list.
        continue;
      }
    }

    return tasks;
  }

  Task _taskFromMap(Map<String, dynamic> data) {
    final metadata = <String, dynamic>{};

    final actionKey = data['key']?.toString();

    if (actionKey != null && actionKey.isNotEmpty) {
      metadata['action_key'] = actionKey;
    }

    return Task(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString(),
      status: TaskStatus.active,
      scope: TaskScope.general,
      rewardPoints: _intValue(data['reward_points']),
      requiresReview: _boolValue(data['requires_approval']),
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      return value != 0;
    }

    return false;
  }
}