import '../models/task.dart';
import 'repositories/repository_factory.dart';
import 'repositories/task_repository.dart';

class TaskService {
  /// The repository is created lazily (not in the constructor) so that
  /// constructing [TaskService] — e.g. as a State field initializer in
  /// ProfilePage — never throws synchronously when the FastAPI
  /// implementation is unavailable. Errors surface through the
  /// repository calls instead, where callers already handle them.
  TaskRepository? _taskRepository;

  TaskRepository get _repository =>
      _taskRepository ??= createTaskRepository();

  Future<List<Task>> getActiveTasks({int limit = 20}) async {
    return _repository.getActiveTasks(limit: limit);
  }

  Future<Task?> getTaskById(String taskId) async {
    return _repository.getTaskById(taskId);
  }

  Future<Task?> createTask(Task task) async {
    return _repository.createTask(task);
  }

  Future<Task?> updateTaskStatus(String taskId, TaskStatus status) async {
    return _repository.updateTaskStatus(taskId, status);
  }
}
