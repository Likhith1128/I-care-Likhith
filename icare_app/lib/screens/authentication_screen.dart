import 'package:flutter/material.dart';

import '../study_scope.dart';
import '../theme.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = true;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final controller = StudyScope.watch(context).controller;
    final name = _nameController.text.trim();
    controller.completeAuthentication(
      name: name,
      age: _isSignUp ? int.parse(_ageController.text.trim()) : null,
    );
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(controller.welcomed ? '/home' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? 'Create your account' : 'Welcome back';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: StudyColors.green,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'I-CARE',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: StudyColors.greenDark,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isSignUp
                          ? 'Create an account to get started with your activity study.'
                          : 'Sign in to continue to your activity study.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: StudyColors.muted),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('auth-name'),
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your name'
                          : null,
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth-age'),
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        validator: (value) {
                          final age = int.tryParse(value?.trim() ?? '');
                          return age != null && age >= 1 && age <= 120
                              ? null
                              : 'Enter a valid age';
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      textInputAction: _isSignUp
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: _isSignUp
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        if (_isSignUp && value.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isSignUp) _submit();
                      },
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth-confirm-password'),
                        controller: _confirmPasswordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Demo only: this app does not verify sign-in credentials with a secure authentication service. Passwords are not saved.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: StudyColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 64,
                      child: FilledButton.icon(
                        key: const Key('auth-submit'),
                        onPressed: _submit,
                        icon: Icon(
                          _isSignUp ? Icons.person_add_alt_1 : Icons.login,
                        ),
                        label: Text(_isSignUp ? 'Create account' : 'Sign in'),
                        style: FilledButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelLarge,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('auth-mode-toggle'),
                      onPressed: _switchMode,
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: StudyColors.greenDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
