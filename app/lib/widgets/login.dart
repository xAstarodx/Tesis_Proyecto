import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'pagina_principal.dart';
import 'register_page.dart';
import '../admin/screens/pantalla_principal.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controladorCorreo = TextEditingController();
  final _controladorContrasena = TextEditingController();
  final _claveFormulario = GlobalKey<FormState>();
  final _servicioSupabase = SupabaseService();
  bool _estaCargando = false;

  @override
  void dispose() {
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;

    setState(() => _estaCargando = true);

    final correo = _controladorCorreo.text.trim();
    final contrasena = _controladorContrasena.text.trim();

    try {
      await _servicioSupabase.iniciarSesion(correo, contrasena);
      
      if (mounted) {
        if (correo == 'noheljosue2307@gmail.com') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PantallaPrincipal()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MyHomePage(title: 'App de Pedidos')),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ocurrió un error inesperado.'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _claveFormulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _controladorCorreo,
                    decoration:
                        const InputDecoration(labelText: 'Correo Electrónico'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingrese su correo';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Ingrese un correo válido';
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controladorContrasena,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingrese la contraseña'
                        : null,
                    onFieldSubmitted: (_) => _iniciarSesion(),
                  ),
                  const SizedBox(height: 20),
                  _estaCargando
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _iniciarSesion,
                          child: const Text('Iniciar sesión'),
                        ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}