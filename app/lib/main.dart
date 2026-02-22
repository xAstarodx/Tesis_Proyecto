import 'package:flutter/material.dart';
import 'widgets/mi_aplicacion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qimcbnumzypyxhnvimjt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpbWNibnVtenlweXhobnZpbWp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwOTIxMjQsImV4cCI6MjA4NjY2ODEyNH0.qaYnTLRkLRpXjkuS194zjBz51IIVYFCa6KuRqJOEBxw',
  );

  runApp(const MyApp());
}
