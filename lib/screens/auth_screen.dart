import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

enum AuthMode { signUp, logIn }

typedef AuthenticateCallback =
    Future<String?> Function({
      required AuthMode mode,
      required String email,
      required String password,
      required String? displayName,
    });

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.mode,
    required this.onBack,
    required this.onContinueAsDemo,
    this.onAuthenticate,
    super.key,
  });

  final AuthMode mode;
  final VoidCallback onBack;
  final ValueChanged<String?> onContinueAsDemo;
  final AuthenticateCallback? onAuthenticate;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _submissionError;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? 'Create a happy space' : 'Welcome back';
    final subtitle = _isSignUp
        ? 'A little space just for you.'
        : 'Let’s make today a little brighter.';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          children: [
            AppPageHeader(title: title, subtitle: subtitle, emoji: '🌸'),
            if (widget.onAuthenticate == null)
              PetalCard(
                color: const Color(0xFFFFE8A9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: PetalPopColors.deepPink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo only: authentication is not connected. '
                        'No account is created or checked, and your details '
                        'are not saved.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PetalPopColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const PetalCard(
                color: Color(0xFFE7F5E9),
                child: Text(
                  'Sign in securely with your PetalPop account. Your password '
                  'is handled by Supabase Auth and is never stored by this app.',
                ),
              ),
            const SizedBox(height: 16),
            PetalCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your name.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: _isSignUp
                          ? TextInputAction.next
                          : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter a password.'
                          : value.length < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Confirm your password.'
                            : value != _passwordController.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.local_florist_rounded),
                      label: Text(
                        _isSubmitting
                            ? 'Please wait…'
                            : widget.onAuthenticate == null
                            ? 'Continue in demo mode'
                            : _isSignUp
                            ? 'Create account'
                            : 'Log In',
                      ),
                    ),
                    if (_submissionError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submissionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.onAuthenticate != null
                  ? 'Your PetalPop account securely stores your profile and progress.'
                  : _isSignUp
                  ? 'Already have an account? You can try the demo Log In instead.'
                  : 'This demo does not verify an account. Your details are not sent anywhere.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authenticate = widget.onAuthenticate;
    if (authenticate == null) {
      widget.onContinueAsDemo(_isSignUp ? _nameController.text.trim() : null);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });
    try {
      final message = await authenticate(
        mode: widget.mode,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _isSignUp ? _nameController.text.trim() : null,
      );
      if (!mounted) return;
      if (message != null) {
        setState(() => _submissionError = message);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submissionError = 'Could not authenticate: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
