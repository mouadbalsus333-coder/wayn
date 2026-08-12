import '../../models/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getActiveTasks({int limit = 20});

  Future<Task?> getTaskById(String taskId);

  Future<Task?> createTask(Task task);

  Future<Task?> updateTaskStatus(String taskId, TaskStatus status);
}
