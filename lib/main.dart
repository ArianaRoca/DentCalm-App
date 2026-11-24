import 'package:flutter/material.dart';

import 'theme/app_icons.dart';

import 'theme/app_theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/app_shell.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await loadThemeMode();

  runApp(const DentCalmApp());
}

class DentCalmApp extends StatelessWidget {
  const DentCalmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DentCalm',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const SplashScreen(next: AuthGate()),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppBackground(
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasData) {
          return const AppShell(inicio: HomeScreen());
        }

        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _ocultarContrasena = true;
  String? errorMessage;

  Future<void> login() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _firebaseError(e.code);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _firebaseError(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      default:
        return 'No se pudo iniciar sesión.';
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// "¿Olvidaste tu contraseña?": envía el correo de restablecimiento de
  /// Firebase Auth. No cambia el inicio de sesión.
  Future<void> _olvideContrasena() async {
    final correo = TextEditingController(text: emailController.text.trim());
    final enviar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Glass.radius),
        ),
        title: Text('Restablecer contraseña', style: AppText.titulo(size: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Te enviaremos un enlace a tu correo para crear una nueva contraseña.',
              style: AppText.texto(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: correo,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(AppIcons.envelopeSimple),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );

    final email = correo.text.trim();
    correo.dispose();
    if (enviar != true || email.isEmpty || !mounted) return;

    String mensaje;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      mensaje =
          'Si existe una cuenta con $email, recibirás un enlace para '
          'restablecer tu contraseña.';
    } on FirebaseAuthException catch (e) {
      mensaje = e.code == 'invalid-email'
          ? 'El correo electrónico no es válido.'
          : 'No se pudo enviar el correo. Inténtalo de nuevo.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(36, 36, 36, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(height: 84)),
                        const SizedBox(height: 28),

                        Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,
                          style: AppText.titulo(size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa con tu cuenta de odontólogo',
                          textAlign: TextAlign.center,
                          style: AppText.texto(color: Colors.grey),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'Correo electrónico',
                          style: AppText.texto(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'nombre@clinica.com',
                            prefixIcon: Icon(AppIcons.envelopeSimple),
                          ),
                        ),
                        const SizedBox(height: 18),

                        Text(
                          'Contraseña',
                          style: AppText.texto(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: _ocultarContrasena,
                          onSubmitted: (_) => loading ? null : login(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(AppIcons.lockSimple),
                            suffixIcon: IconButton(
                              tooltip: _ocultarContrasena
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(
                                _ocultarContrasena
                                    ? AppIcons.eye
                                    : AppIcons.eyeSlash,
                              ),
                              onPressed: () => setState(
                                () => _ocultarContrasena = !_ocultarContrasena,
                              ),
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _olvideContrasena,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),

                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  AppIcons.warningCircle,
                                  color: AppTheme.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: AppText.texto(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: AppTheme.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else
                          const SizedBox(height: 6),

                        PrimaryButton(
                          label: loading ? 'Ingresando...' : 'Ingresar',
                          loading: loading,
                          onPressed: login,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿No tienes cuenta?',
                              style: AppText.texto(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: const Text('Crear cuenta'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sol / luna arriba a la derecha
            const Positioned(
              top: 16,
              right: 16,
              child: SafeArea(child: _TemaFlotante()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón sol/luna sobre una pequeña superficie de vidrio.
class _TemaFlotante extends StatelessWidget {
  const _TemaFlotante();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.all(2),
      radius: 16,
      child: ThemeToggleButton(),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  String? errorMessage;

  Future<void> register() async {
    if (passwordController.text != confirmController.text) {
      setState(() {
        errorMessage = 'Las contraseñas no coinciden.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      await credential.user?.updateDisplayName(nameController.text.trim());

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _registerError(e.code);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _registerError(String code) {
    switch (code) {
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      default:
        return 'No se pudo crear la cuenta.';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crear cuenta'),
          actions: const [ThemeToggleButton(), SizedBox(width: 10)],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/A_icono.png',
                        height: 64,
                        semanticLabel: 'DentCalm',
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Registro del odontólogo',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 25),

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(AppIcons.user),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(AppIcons.envelopeSimple),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(AppIcons.lockSimple),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(AppIcons.lockSimple),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: loading ? 'Creando cuenta...' : 'Crear cuenta',
                          icon: AppIcons.userPlus,
                          loading: loading,
                          onPressed: register,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
