
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../core/navigation/wayn_shell.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState()=>_AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  final _auth=AuthService();
  User? _user; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try { _user=await _auth.getCurrentUser(); } catch (_) {}
    if(mounted)setState(()=>_loading=false);
  }
  @override Widget build(BuildContext context){
    if(_loading)return const Scaffold(body: Center(child:CircularProgressIndicator()));
    return _user==null ? LoginPage(onAuthenticated:(u)=>setState(()=>_user=u)) : WaynShell(user:_user!);
  }
}
