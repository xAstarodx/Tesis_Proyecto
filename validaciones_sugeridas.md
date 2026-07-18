# Sugerencias de Validaciones para el Proyecto

Este documento detalla una serie de validaciones recomendadas para mejorar la seguridad, la robustez y la experiencia de usuario (UX) del sistema. Se especifican los archivos involucrados, el **porqué** es necesaria cada validación y el **cómo** implementarla con ejemplos de código.

---

## Índice

1. [Validación de Complejidad de Contraseña en Registro](#1-validación-de-complejidad-de-contraseña-en-registro)
2. [Confirmación de Contraseña en Registro](#2-confirmación-de-contraseña-en-registro)
3. [Validación de Métodos de Pago según Selección en Carrito](#3-validación-de-métodos-de-pago-según-selección-en-carrito)
4. [Validación de Rango Numérico (Precios y Stock) en el Panel de Administración](#4-validación-de-rango-numérico-precios-y-stock-en-el-panel-de-administración)
5. [Roles de Usuario Dinámicos (Evitar Hardcoding de Administrador)](#5-roles-de-usuario-dinámicos-evitar-hardcoding-de-administrador)
6. [Validación de Formato en Referencias de Pago Móvil](#6-validación-de-formato-en-referencias-de-pago-móvil)

---

### 1. Validación de Complejidad de Contraseña en Registro

* **Archivo afectado:** [register_page.dart](file:///workspaces/Tesis_Proyecto/lib/widgets/register_page.dart) (Líneas 252-255)
* **Por qué es necesaria:**
  Actualmente, el sistema solo valida que la contraseña tenga 6 o más caracteres (`value.length < 6`). Esto expone a los usuarios a crear contraseñas extremadamente débiles (ej. `123456`), facilitando ataques de fuerza bruta y comprometiendo sus cuentas.
* **Cómo implementarla:**
  Podemos utilizar expresiones regulares para asegurar que la contraseña contenga al menos una letra mayúscula, una letra minúscula, un número y un carácter especial.

```dart
// Código sugerido para el validator en register_page.dart
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Por favor ingresa una contraseña';
  }
  if (value.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres';
  }
  // Al menos una mayúscula, una minúscula, un número y un carácter especial
  final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$');
  if (!regex.hasMatch(value)) {
    return 'Debe incluir mayúscula, minúscula, número y carácter especial (@$!%*?&)';
  }
  return null;
}
```

---

### 2. Confirmación de Contraseña en Registro

* **Archivo afectado:** [register_page.dart](file:///workspaces/Tesis_Proyecto/lib/widgets/register_page.dart)
* **Por qué es necesaria:**
  No existe un campo para "Confirmar Contraseña". Si el usuario comete un error tipográfico escribiendo su contraseña durante el registro, su cuenta se creará con una clave que no conoce, bloqueándolo inmediatamente sin posibilidad de iniciar sesión.
* **Cómo implementarla:**
  Agregar un segundo controlador y un segundo `TextFormField` para repetir la contraseña y validar que ambos valores coincidan.

```dart
// 1. Agregar el controlador en el State
final _controladorConfirmarContrasena = TextEditingController();

// 2. Agregar el campo en la interfaz (dentro del Form)
TextFormField(
  controller: _controladorConfirmarContrasena,
  obscureText: !_mostrarContrasena,
  decoration: const InputDecoration(
    labelText: 'Confirmar Contraseña',
    prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
  ),
  validator: (value) {
    if (value != _controladorContrasena.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  },
),
```

---

### 3. Validación de Métodos de Pago según Selección en Carrito

* **Archivo afectado:** [carrito.dart](file:///workspaces/Tesis_Proyecto/lib/widgets/carrito.dart) (Líneas 163-172, 180)
* **Por qué es necesaria:**
  Actualmente, la aplicación obliga a que el usuario introduzca una referencia o foto del pago móvil (`_referenciaController.text.trim().isEmpty && _comprobanteImage == null`), y el ID del método de pago está hardcodeado a `3` (Pago Móvil). Si en el futuro el usuario elige "Efectivo" o "Tarjeta", solicitar estas evidencias de pago móvil causará confusión y errores de validación innecesarios.
* **Cómo implementarla:**
  Validar condicionalmente según el método de pago seleccionado por el usuario en la interfaz.

```dart
// En _procesarEnvio dentro de carrito.dart:
void _procesarEnvio(List<Map<String, dynamic>> items) async {
  // ...
  
  // Asumiendo que guardamos el formaPagoId seleccionado en una variable
  final pagoMovilId = 3; 
  
  if (formaPagoSeleccionadoId == pagoMovilId) {
    if (_referenciaController.text.trim().isEmpty && _comprobanteImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para Pago Móvil, debe ingresar la referencia o adjuntar el comprobante.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
  }
  
  // Enviar con el ID de forma de pago correspondiente y no hardcodeado a 3
  await _supabaseService.enviarPedido(
    items: items,
    horaRecogida: _horaRecogida!,
    formaPagoId: formaPagoSeleccionadoId, // Dinámico
    referencia: _referenciaController.text.trim().isEmpty ? null : _referenciaController.text.trim(),
    comprobanteImage: _comprobanteImage,
    nota: _mensajeAdminController.text.trim(),
  );
}
```

---

### 4. Validación de Rango Numérico (Precios y Stock) en el Panel de Administración

* **Archivo afectado:** [pantalla_principal.dart](file:///workspaces/Tesis_Proyecto/lib/admin/screens/pantalla_principal.dart) (Líneas 2604-2624)
* **Por qué es necesaria:**
  El formulario para crear/editar productos valida que el stock y el precio sean números válidos (`int.tryParse` y `double.tryParse`), pero no verifica si son valores positivos. Un administrador podría introducir accidentalmente precios negativos (ej. `-10.0$`) o stock negativo, lo que corrompería la base de datos y causaría pérdidas financieras o fallos en el inventario.
* **Cómo implementarla:**
  Asegurar que el precio sea estrictamente mayor a cero y que el stock sea mayor o igual a cero.

```dart
// Validación para stock/cantidad
TextFormField(
  controller: controladorCantidad,
  decoration: const InputDecoration(labelText: 'Cantidad'),
  keyboardType: TextInputType.number,
  validator: (v) {
    if (v == null || v.trim().isEmpty) return 'La cantidad es obligatoria';
    final cantidad = int.tryParse(v);
    if (cantidad == null) return 'Número inválido';
    if (cantidad < 0) return 'La cantidad no puede ser negativa';
    return null;
  },
),

// Validación para precio
TextFormField(
  controller: controladorPrecio,
  decoration: const InputDecoration(labelText: 'Precio (USD)'),
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  validator: (v) {
    if (v == null || v.trim().isEmpty) return 'El precio es obligatorio';
    final precio = double.tryParse(v.replaceAll(',', '.'));
    if (precio == null) return 'Precio inválido';
    if (precio <= 0) return 'El precio debe ser mayor a cero';
    return null;
  },
),
```

---

### 5. Roles de Usuario Dinámicos (Evitar Hardcoding de Administrador)

* **Archivo afectado:** [login.dart](file:///workspaces/Tesis_Proyecto/lib/widgets/login.dart) (Líneas 35-48, 73-85)
* **Por qué es necesaria:**
  El control de acceso al panel de administración está hardcodeado con el correo `noheljosue2307@gmail.com`. Esto presenta un riesgo de seguridad crítico y un problema de mantenimiento a largo plazo:
  1. Si un atacante intercepta la app o modifica el flujo del cliente, podría saltarse la validación visual y entrar a la interfaz de administración.
  2. Si el correo del administrador cambia o se quiere agregar a un segundo administrador, se requiere volver a compilar y publicar una actualización de la aplicación móvil.
* **Cómo implementarla:**
  1. Utilizar las políticas de Supabase (RLS - Row Level Security) para proteger las tablas de administración (`productos`, `pedidos`, etc.) basados en roles de usuario.
  2. Leer el rol de usuario directamente desde la tabla `usuario` en la base de datos o mediante la metadata de Supabase Auth tras iniciar sesión.

```dart
// En SupabaseService o Login:
Future<bool> esUsuarioAdmin(String email) async {
  try {
    final response = await _cliente
        .from('usuario')
        .select('rol_id')
        .eq('correo', email)
        .maybeSingle();
    
    if (response != null && response['rol_id'] == 2) {
      return true;
    }
  } catch (e) {
    debugPrint('Error al validar rol de admin: $e');
  }
  return false;
}

// Y en login.dart usar el resultado dinámico:
final isAdmin = await _servicioSupabase.esUsuarioAdmin(correo);
if (isAdmin) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PantallaPrincipal()));
} else {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyHomePage(title: 'App de Pedidos')));
}
```

---

### 6. Validación de Formato en Referencias de Pago Móvil

* **Archivo afectado:** [carrito.dart](file:///workspaces/Tesis_Proyecto/lib/widgets/carrito.dart)
* **Por qué es necesaria:**
  Al pagar por Pago Móvil, los usuarios a veces cometen errores al escribir la referencia bancaria (escriben textos aleatorios, colocan letras donde solo van números, etc.). Una referencia mal ingresada dificulta la conciliación bancaria para el administrador.
* **Cómo implementarla:**
  Establecer que el campo solo admita números y que cumpla con una longitud mínima estándar (por ejemplo, entre 4 y 8 dígitos según los bancos correspondientes).

```dart
TextFormField(
  controller: _referenciaController,
  decoration: const InputDecoration(
    labelText: 'Referencia del Pago Móvil',
  ),
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly, // Evita ingresar letras
  ],
  validator: (value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 4 || value.length > 8) {
        return 'La referencia suele tener entre 4 y 8 dígitos';
      }
    }
    return null;
  },
)
```
