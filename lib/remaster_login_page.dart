import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entry point used by the adaptive remaster. Authentication itself remains
/// owned by [MyApp] so Google, e-mail and local mode keep their existing flow.
class RemasterLoginPage extends StatefulWidget {
  const RemasterLoginPage({
    super.key,
    required this.onLocalMode,
    required this.onSignedIn,
    required this.onGoogleSignIn,
  });

  final VoidCallback onLocalMode;
  final Future<void> Function() onSignedIn;
  final Future<void> Function() onGoogleSignIn;

  @override
  State<RemasterLoginPage> createState() => _RemasterLoginPageState();
}

class _RemasterLoginPageState extends State<RemasterLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _googleLoading = false;
  bool _emailLoading = false;
  bool _emailExpanded = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _startGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await widget.onGoogleSignIn();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Nie udało się połączyć z Google. Spróbuj ponownie.',
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Wpisz adres e-mail oraz hasło.');
      return;
    }
    setState(() {
      _error = null;
      _emailLoading = true;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (Supabase.instance.client.auth.currentSession != null) {
        await widget.onSignedIn();
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Wpisz adres e-mail oraz hasło.');
      return;
    }
    setState(() {
      _error = null;
      _emailLoading = true;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        setState(
          () => _error = 'Konto utworzone. Sprawdź skrzynkę e-mail, jeśli wymagane jest potwierdzenie.',
        );
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final welcome = _WelcomePanel(wide: wide);
            final form = _SignInCard(
              email: _email,
              password: _password,
              error: _error,
              emailExpanded: _emailExpanded,
              googleLoading: _googleLoading,
              emailLoading: _emailLoading,
              onGoogle: _startGoogle,
              onEmailExpand: () => setState(
                () => _emailExpanded = !_emailExpanded,
              ),
              onEmailSignIn: _signInWithEmail,
              onEmailSignUp: _signUpWithEmail,
              onLocalMode: widget.onLocalMode,
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    scheme.surfaceContainerLowest,
                  ],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 32 : 24),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 6, child: welcome),
                              const SizedBox(width: 48),
                              Expanded(flex: 5, child: form),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [welcome, const SizedBox(height: 32), form],
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.radio_button_checked_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text('Dzień po dniu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Mniej chaosu.\nWięcej miejsca na to, co ważne.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 430 : 560),
            child: Text(
              'Zadania, notatki i Twój plan — bezpiecznie synchronizowane między urządzeniami.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.email,
    required this.password,
    required this.error,
    required this.emailExpanded,
    required this.googleLoading,
    required this.emailLoading,
    required this.onGoogle,
    required this.onEmailExpand,
    required this.onEmailSignIn,
    required this.onEmailSignUp,
    required this.onLocalMode,
  });

  final TextEditingController email, password;
  final String? error;
  final bool emailExpanded, googleLoading, emailLoading;
  final VoidCallback onGoogle, onEmailExpand, onEmailSignIn, onEmailSignUp, onLocalMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zaloguj się', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Wybierz sposób, który jest dla Ciebie wygodny.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('remaster-google-sign-in'),
              onPressed: googleLoading ? null : onGoogle,
              icon: googleLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.g_mobiledata_rounded),
              label: Text(
                googleLoading ? 'Łączę z Google…' : 'Kontynuuj z Google',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            TextButton(
              onPressed: onLocalMode,
              child: const Text('Tryb lokalny'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEmailExpand,
              icon: Icon(
                emailExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.mail_outline_rounded,
              ),
              label: Text(
                emailExpanded ? 'Ukryj logowanie e-mailem' : 'Zaloguj e-mailem',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: emailExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Adres e-mail',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Hasło',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: emailLoading ? null : onEmailSignIn,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(emailLoading ? 'Logowanie…' : 'Zaloguj e-mail'),
                          ),
                          TextButton(
                            onPressed: emailLoading ? null : onEmailSignUp,
                            child: const Text('Załóż konto'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
