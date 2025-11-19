import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/outbox_service.dart';
import '../services/auth_service.dart';
//import '../services/inbox_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getString('remembered_email');
    if (remembered != null && remembered.isNotEmpty) {
      _emailCtrl.text = remembered;
      setState(() {});
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 👉 Intenta ONLINE; si falla por red, AuthService hace fallback OFFLINE
      final result = await AuthService.login(email, password);

      if (result == null) {
        setState(() {
          _loading = false;
          _error =
              'No se pudo iniciar sesión. Si es tu primer ingreso en este dispositivo, requiere conexión.';
        });
        return;
      }

      // Guarda email recordado (UX)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remembered_email', email);

      // Si fue ONLINE (hay token), sincroniza catálogos y outbox
      if (!result.offline &&
          result.token != null &&
          result.productorId != null) {
        try {
          await SyncService.sincronizarCatalogos(
            result.token!,
            result.productorId!,
          );
          await OutboxService.trySyncAll();
          //await InboxService.syncFromServer();
        } catch (_) {
          // No bloquees acceso por fallo de sync
        }
      }

      // En ambos casos inicia escucha de conectividad
      await OutboxService.startConnectivitySync();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });

      if (result.offline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modo offline: usarás datos locales.')),
        );
      }

      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'token': result.token, // null en offline
          'productorId': result.productorId,
          'offline': result.offline,
        },
      );
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error =
            'Error de conexión o modo offline no disponible en este dispositivo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Intención de Siembra')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Tamaño del logo adaptativo
                final logoMaxWidth = constraints.maxWidth;
                final logoHeight = logoMaxWidth >= 350 ? 88.0 : 68.0;

                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LOGO PNG
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            bottom: 20.0,
                          ),
                          child: Image.asset(
                            'assets/images/logogc.png', // <-- asegúrate que el path coincida
                            height: logoHeight,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),

                        // Título opcional con color de marca
                        Text(
                          'Bienvenido',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'usuario@dominio.com',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Ingrese su email';
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(val.trim())) {
                              return 'Email inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            ),
                          ),
                          validator: (val) => (val == null || val.isEmpty)
                              ? 'Ingrese su contraseña'
                              : null,
                          onFieldSubmitted: (_) => _login(),
                        ),

                        const SizedBox(height: 16),

                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Ingresar'),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Texto de ayuda / versión / modo offline (opcional)
                        Opacity(
                          opacity: 0.7,
                          child: Text(
                            'Si es tu primer ingreso en este dispositivo,\nrequiere conexión a internet.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
