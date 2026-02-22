import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _claveFormulario = GlobalKey<FormState>();
  final _controladorUsuario = TextEditingController();
  final _controladorCorreo = TextEditingController();
  final _controladorContrasena = TextEditingController();
  final _servicioSupabase = SupabaseService();
  bool _estaCargando = false;

  @override
  void dispose() {
    _controladorUsuario.dispose();
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;

    setState(() => _estaCargando = true);

    final usuario = _controladorUsuario.text.trim();
    final correo = _controladorCorreo.text.trim();

    try {
      await _servicioSupabase.registrarUsuario(
        correo,
        _controladorContrasena.text.trim(),
        usuario: usuario,
        nombre: usuario,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ya te haz registrado, porfavor haz la verificacion de que tu correo es real en la menu principal de tu gmail .')),
        );
        Navigator.pop(context);
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
              content: Text('Ocurrió un error .'),
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
        title: const Text('Registrarse'),
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Por favor ingresa tu correo';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Ingresa un correo válido';
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controladorUsuario,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa un nombre de usuario valido';
                      }
                      if (value.contains('@') || value.contains(' ')) {
                        return 'El usuario no puede contener "@" o espacios';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controladorContrasena,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6) ? 'La contraseña debe tener al menos 6 caracteres' : null,
                    onFieldSubmitted: (_) => _registrar(),
                  ),
                  const SizedBox(height: 20),
                  _estaCargando
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _registrar,
                          child: const Text('Registrarse'),
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