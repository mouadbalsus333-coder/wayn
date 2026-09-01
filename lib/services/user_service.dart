import '../models/user.dart';
import 'repositories/repository_factory.dart';
import 'repositories/user_repository.dart';

class UserService {
  final UserRepository _userRepository;

  UserService({UserRepository? userRepository})
    : _userRepository = userRepository ?? createUserRepository();

  Future<User?> getCurrentUser() async {
    return _userRepository.getCurrentUser();
  }

  Future<User?> getUserById(String id) async {
    return _userRepository.getUserById(id);
  }

  Future<List<User>> searchUsers(String query) async {
    return _userRepository.searchUsers(query);
  }

  Future<User?> createOrUpdateUser(User user) async {
    return _userRepository.createOrUpdateUser(user);
  }

  Future<int> getMyPoints() async {
    return _userRepository.getMyPoints();
  }
}
