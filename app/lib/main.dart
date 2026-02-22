// Importa el paquete de Material Design de Flutter para los widgets de la UI.
import 'package:flutter/material.dart';
// Importa el widget principal de nuestra aplicación.
import 'widgets/mi_aplicacion.dart';
// Importa el paquete de Supabase para la integración con el backend.
import 'package:supabase_flutter/supabase_flutter.dart';

// La función `main` es el punto de entrada de toda la aplicación.
// Se marca como `async` porque necesitamos esperar a que Supabase se inicialice.
void main() async {
  // Asegura que todos los bindings de Flutter estén inicializados antes de ejecutar código asíncrono.
  // Es necesario para poder llamar a Supabase.initialize() antes de runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa el cliente de Supabase.
  // Esto configura la conexión con tu backend de Supabase usando la URL y la clave anónima (anonKey).
  await Supabase.initialize(
    url: 'https://qimcbnumzypyxhnvimjt.supabase.co', // URL de tu proyecto en Supabase.
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpbWNibnVtenlweXhobnZpbWp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwOTIxMjQsImV4cCI6MjA4NjY2ODEyNH0.qaYnTLRkLRpXjkuS194zjBz51IIVYFCa6KuRqJOEBxw', // Clave pública (segura para exponer en el cliente).
  );

  // Inicia la aplicación Flutter, inflando el widget raíz `MyApp` y mostrándolo en la pantalla.
  runApp(const MyApp());
}
