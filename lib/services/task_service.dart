import '../models/task.dart';
import 'repositories/repository_factory.dart';
import 'repositories/task_repository.dart';

class TaskService {
  final TaskRepository _taskRepository;

  TaskService({TaskRepository? taskRepository})
    : _taskRepository = taskRepository ?? createTaskRepository();

  Future<List<Task>> getActiveTasks({int limit = 20}) async {
    return _taskRepository.getActiveTasks(limit: limit);
  }

  Future<Task?> getTaskById(String taskId) async {
    return _taskRepository.getTaskById(taskId);
  }

  Future<Task?> createTask(Task task) async {
    return _taskRepository.createTask(task);
  }

  Future<Task?> updateTaskStatus(String taskId, TaskStatus status) async {
    return _taskRepository.updateTaskStatus(taskId, status);
  }
}
