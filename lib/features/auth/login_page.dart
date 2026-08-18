
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final ValueChanged<User> onAuthenticated;
  const LoginPage({super.key,required this.onAuthenticated});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final email=TextEditingController(),password=TextEditingController();
  final auth=AuthService(); bool loading=false; String? error; bool obscure=true;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  Future<void> _login() async {
    if(email.text.trim().isEmpty||password.text.isEmpty){setState(()=>error='أدخل البريد الإلكتروني وكلمة المرور');return;}
    setState(()=>loading=true); error=null;
    try { final u=await auth.login(email:email.text.trim(),password:password.text); if(u!=null&&mounted)widget.onAuthenticated(u); }
    catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFFF7F9FC),
    body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:480),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      SizedBox(height:30),_Brand(),SizedBox(height:36),
      Text('مرحباً بك من جديد',textDirection:TextDirection.rtl,textAlign:TextAlign.right,style:TextStyle(fontSize:27,fontWeight:FontWeight.w800,color:Color(0xFF172033))),
      SizedBox(height:8),Text('سجّل دخولك واستكشف وين من حولك',textDirection:TextDirection.rtl,textAlign:TextAlign.right,style:TextStyle(color:Color(0xFF7A8494))),
      SizedBox(height:28),
      _Label('البريد الإلكتروني'),SizedBox(height:7),
      _Field(controller:email,hint:'example@email.com',keyboard:TextInputType.emailAddress),
      SizedBox(height:16),_Label('كلمة المرور'),SizedBox(height:7),
      Builder(builder:(context)=>TextField(controller:password,obscureText:obscure,textDirection:TextDirection.ltr,decoration:_decoration('••••••••').copyWith(suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_off_outlined:Icons.visibility_outlined))))),
      if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,textDirection:TextDirection.rtl,style:const TextStyle(color:Color(0xFFD34E4E),fontSize:12))),
      SizedBox(height:24),
      FilledButton(onPressed:loading?null:_login,style:FilledButton.styleFrom(backgroundColor:const Color(0xFF18A99A),minimumSize:const Size.fromHeight(54),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:loading?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('تسجيل الدخول',style:TextStyle(fontWeight:FontWeight.w800))),
      SizedBox(height:14),
      OutlinedButton(onPressed:loading?null:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>RegisterPage(onAuthenticated:widget.onAuthenticated))),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(54),side:const BorderSide(color:Color(0xFFDCE2E8)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:const Text('إنشاء حساب جديد',style:TextStyle(color:Color(0xFF172033),fontWeight:FontWeight.w700))),
    ]))))));
}
class _Brand extends StatelessWidget{const _Brand();@override Widget build(BuildContext c)=>Row(mainAxisAlignment:MainAxisAlignment.end,children:[Container(width:52,height:52,decoration:BoxDecoration(color:const Color(0xFFE5F8F5),borderRadius:BorderRadius.circular(17)),child:const Icon(Icons.location_on_rounded,color:Color(0xFF18A99A),size:30)),const SizedBox(width:12),const Text('WAYN',style:TextStyle(fontSize:29,fontWeight:FontWeight.w900,color:Color(0xFF18A99A)))]);}
class _Label extends StatelessWidget{final String t;const _Label(this.t);@override Widget build(BuildContext c)=>Text(t,textDirection:TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF30394A)));}
class _Field extends StatelessWidget{final TextEditingController controller;final String hint;final TextInputType keyboard;const _Field({required this.controller,required this.hint,required this.keyboard});@override Widget build(BuildContext c)=>TextField(controller:controller,keyboardType:keyboard,textDirection:TextDirection.ltr,decoration:_decoration(hint));}
InputDecoration _decoration(String hint)=>InputDecoration(hintText:hint,hintStyle:const TextStyle(color:Color(0xFFA1A9B5)),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xFFE3E8ED))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xFFE3E8ED))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xFF18A99A),width:1.5)),contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16));
