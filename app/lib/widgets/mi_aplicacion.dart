// Importa el paquete de Material Design de Flutter.
import 'package:flutter/material.dart';
// Importa la página de inicio de sesión, que será la primera pantalla.
import 'login.dart';

// `MyApp` es el widget raíz de la aplicación.
// Es un `StatelessWidget` porque su estado no cambia con el tiempo.
// Su única función es configurar la aplicación.
class MyApp extends StatelessWidget {
  // Constructor del widget. `super.key` pasa la clave al widget padre.
  const MyApp({super.key});

  @override
  // El método `build` describe cómo se debe construir la interfaz de usuario del widget.
  Widget build(BuildContext context) {
    // `MaterialApp` es un widget que envuelve varias funcionalidades que son comunes en las apps de Material Design.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Título de la aplicación, usado por el sistema operativo.
      title: 'APP de Pedidos',
      // `theme` define el aspecto visual de la aplicación.
      theme: ThemeData(
        // `colorScheme` define la paleta de colores de la aplicación.
        // `fromSeed` genera una paleta completa a partir de un solo color semilla.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(139, 12, 63, 230)),
      ),
      // `home` es el widget que se mostrará como pantalla principal al iniciar la app.
      home: const LoginPage(),
    );
  }
}
