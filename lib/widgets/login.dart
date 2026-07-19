import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'pagina_principal.dart';
import 'register_page.dart';
import '../admin/screens/pantalla_principal.dart';
import '../theme/app_theme.dart';

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
  bool _mostrarContrasena = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final session = data.session;
      if (session != null && mounted) {
        final correo = session.user.email;
        if (correo == null) return;

        await _servicioSupabase.asegurarUsuario(
          email: correo,
          nombre: session.user.userMetadata?['nombre'] as String?,
        );

        final isAdmin = await _servicioSupabase.esAdmin(correo);
        if (!mounted) return;

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PantallaPrincipal()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MyHomePage(title: 'App de Pedidos'),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    _authSubscription?.cancel();
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
        final isAdmin = await _servicioSupabase.esAdmin(correo);
        if (!mounted) return;

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PantallaPrincipal()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MyHomePage(title: 'App de Pedidos'),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocurrió un error inesperado.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  Future<void> _iniciarSesionGoogle() async {
    setState(() => _estaCargando = true);
    try {
      await _servicioSupabase.iniciarSesionGoogle();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con Google: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
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
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxHeight < 600;
              return Column(
                children: [

                  Expanded(
                    flex: isSmall ? 1 : 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          if (!isSmall)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.restaurant_menu,
                                size: 64,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          if (!isSmall) const SizedBox(height: 24),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'Cafetín ISABORES',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'IUTEPAL',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _claveFormulario,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '¡Bienvenido!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Inicia sesión para continuar',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                controller: _controladorCorreo,
                                decoration: const InputDecoration(
                                  labelText: 'Correo Electrónico',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Ingrese su correo';
                                  }
                                  if (!RegExp(
                                    r'^[^@]+@[^@]+\.[^@]+',
                                  ).hasMatch(v)) {
                                    return 'Ingrese un correo válido';
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _controladorContrasena,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppTheme.primaryColor,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _mostrarContrasena
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppTheme.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _mostrarContrasena =
                                            !_mostrarContrasena;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: !_mostrarContrasena,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Ingrese la contraseña'
                                    : null,
                                onFieldSubmitted: (_) => _iniciarSesion(),
                              ),
                              const SizedBox(height: 32),
                              _estaCargando
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton(
                                      onPressed: _iniciarSesion,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        backgroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'O continúa con',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _estaCargando
                                      ? null
                                      : _iniciarSesionGoogle,
                                  icon: const Icon(
                                    Icons.login_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                  label: const Text(
                                    'Google',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '¿No tienes cuenta?',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegisterPage(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Regístrate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
