import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://jjqprspiljblhqcsvtzv.supabase.co',
    publishableKey: 'sb_publishable_TDW4AC7x53mj3A1ykUGWpA_EnAyYgdt',
  );
}
