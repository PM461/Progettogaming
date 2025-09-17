import 'package:flutter/material.dart';
import 'package:front_gaming/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      if (success) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        setState(() => _error = 'Credenziali errate');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Errore di rete. Riprova.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.googleLogin();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/splash');
    } catch (e) {
      if (mounted) setState(() => _error = 'Accesso Google fallito');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0E91DD);
    const accent = Color(0xFFEE3FD0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 140,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Image.asset('images/logoestesow.png', height: 28),
              const SizedBox(width: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('Indietro'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // --- SFONDO ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF141414), Color(0xFF0B0B0B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withOpacity(0.25),
                      Colors.transparent,
                      accent.withOpacity(0.25),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // --- CONTENUTO ---
          LayoutBuilder(
            builder: (context, cons) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: (cons.maxHeight * 0.12).clamp(40.0, 120.0),
                  left: 20,
                  right: 20,
                  bottom: 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo & titolo
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('images/logoestesow.png',
                                    height: 48),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Accedi a Ludos',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Organizza giochi, traccia progressi, unisciti alla community.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 18),

                            // Messaggio errore
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    enabled: !_loading,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.alternate_email),
                                    ),
                                    validator: (v) {
                                      final t = v?.trim() ?? '';
                                      if (t.isEmpty) return 'Inserisci l’email';
                                      if (!t.contains('@') ||
                                          !t.contains('.')) {
                                        return 'Email non valida';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    enabled: !_loading,
                                    obscureText: _obscure,
                                    onFieldSubmitted: (_) => _login(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        tooltip: _obscure
                                            ? 'Mostra password'
                                            : 'Nascondi password',
                                        onPressed: _loading
                                            ? null
                                            : () => setState(
                                                () => _obscure = !_obscure),
                                        icon: Icon(_obscure
                                            ? Icons.visibility
                                            : Icons.visibility_off),
                                      ),
                                    ),
                                    validator: (v) {
                                      if ((v ?? '').isEmpty) {
                                        return 'Inserisci la password';
                                      }
                                      if ((v ?? '').length < 6) {
                                        return 'Minimo 6 caratteri';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Pulsante Login
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Accedi'),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Divisore "oppure"
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white12,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('oppure'),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white12,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Google
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loginWithGoogle,
                                icon: const Icon(Icons.login),
                                label: const Text('Accedi con Google'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.5)),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Registrazione (se prevista)
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pushNamed(
                                        context,
                                        '/register',
                                      ),
                              child:
                                  const Text('Non hai un account? Registrati'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // --- OVERLAY LOADING ---
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: Image.asset(
                    'images/logow.gif',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
