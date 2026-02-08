import 'package:flutter/material.dart';
import 'pagina_principal.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APP de Pedidos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(139, 12, 63, 230)),
      ),
      home: const MyHomePage(title: 'App de Pedidos'),
    );
  }
}
