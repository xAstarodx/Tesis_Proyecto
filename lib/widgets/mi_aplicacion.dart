import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'pagina_principal.dart';
import '../admin/screens/pantalla_principal.dart';
import '../theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cafetín ISABORES',
      theme: AppTheme.lightTheme,

      home: _obtenerPaginaInicial(),
    );
  }

  Widget _obtenerPaginaInicial() {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    const String adminEmail = 'noheljosue2307@gmail.com';

    if (session != null) {

      if (session.user.email == adminEmail) {
        return const PantallaPrincipal();
      }
      return const MyHomePage(title: 'App de Pedidos');
    }

    return const LoginPage();
  }
}
