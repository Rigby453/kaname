// Экран входа / регистрации (406-ФЗ: основной идентификатор — телефон).
// Переключение режимов login/register; вход в офлайн-режиме без аккаунта.
// После успеха навигацию выполняет redirect в routerProvider (по смене статуса).
// Google/Apple OAuth удалены — иностранные OAuth-провайдеры запрещены 406-ФЗ.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/api/api_client.dart';
import 'auth_controller.dart';

// ---------------------------------------------------------------------------
// Вспомогательный тип: какой идентификатор использует пользователь
// ---------------------------------------------------------------------------

enum _IdentifierType { phone, email }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  // По умолчанию — телефон (требование 406-ФЗ)
  _IdentifierType _identifierType = _IdentifierType.phone;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Валидация
  // ---------------------------------------------------------------------------

  /// Проверяет, что номер похож на российский (+7, 7 или 8, всего ~11 цифр).
  bool _isValidRuPhone(String value) {
    // Принимаем: +7XXXXXXXXXX, 7XXXXXXXXXX, 8XXXXXXXXXX
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return false;
    return digits.startsWith('7') || digits.startsWith('8');
  }

  /// Нормализует номер к E.164: +7XXXXXXXXXX.
  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    // Заменяем ведущую 8 на 7
    final normalized = digits.startsWith('8') ? '7${digits.substring(1)}' : digits;
    return '+$normalized';
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // --- Валидация идентификатора ---
    String? email;
    String? phone;

    if (_identifierType == _IdentifierType.phone) {
      final rawPhone = _phoneController.text.trim();
      if (rawPhone.isEmpty) {
        setState(() => _error = 'Please enter your phone number');
        return;
      }
      if (!_isValidRuPhone(rawPhone)) {
        setState(() => _error = 'Enter a valid Russian phone number (+7…)');
        return;
      }
      phone = _normalizePhone(rawPhone);
    } else {
      email = _emailController.text.trim();
      if (email.isEmpty) {
        setState(() => _error = 'Please enter your email');
        return;
      }
    }

    // --- Валидация пароля и имени ---
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (!_isLogin && password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_isLogin) {
        await auth.login(email: email, phone: phone, password: password);
      } else {
        await auth.register(
          email: email,
          phone: phone,
          password: password,
          name: name,
        );
      }
      // Навигацию выполнит redirect роутера; виджет может быть уже размонтирован.
    } on ApiException catch (e) {
      // Сообщение бэкенда (напр. "Use a Russian email provider") показываем как есть.
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueOffline() async {
    await ref.read(authControllerProvider.notifier).continueOffline();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kaizen', style: textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    "The important stuff won't slip.",
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),

                  // --- Phone / Email toggle ---
                  _IdentifierToggle(
                    selected: _identifierType,
                    onChanged: _loading
                        ? null
                        : (type) => setState(() {
                              _identifierType = type;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 16),

                  // --- Name field (sign-up only) ---
                  if (!_isLogin) ...[
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // --- Identifier field ---
                  if (_identifierType == _IdentifierType.phone)
                    TextField(
                      key: const ValueKey('phone_field'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Phone (+7…)',
                        hintText: '+7 999 123-45-67',
                      ),
                    )
                  else
                    TextField(
                      key: const ValueKey('email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _submit(),
                  ),

                  // --- Error message ---
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // --- Primary action ---
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Log in' : 'Sign up'),
                  ),
                  const SizedBox(height: 8),

                  // --- Toggle login/register ---
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _error = null;
                            }),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign up"
                          : 'Already have an account? Log in',
                    ),
                  ),

                  // --- Forgot password (login only) ---
                  if (_isLogin)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),

                  // --- Offline mode ---
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : _continueOffline,
                    child: const Text('Continue offline'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone / Email toggle widget
// ---------------------------------------------------------------------------

class _IdentifierToggle extends StatelessWidget {
  const _IdentifierToggle({
    required this.selected,
    required this.onChanged,
  });

  final _IdentifierType selected;
  final ValueChanged<_IdentifierType>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_IdentifierType>(
      segments: const [
        ButtonSegment(
          value: _IdentifierType.phone,
          label: Text('Phone'),
          icon: Icon(Icons.phone_outlined),
        ),
        ButtonSegment(
          value: _IdentifierType.email,
          label: Text('Email'),
          icon: Icon(Icons.email_outlined),
        ),
      ],
      selected: {selected},
      onSelectionChanged: onChanged == null
          ? null
          : (newSelection) => onChanged!(newSelection.first),
      showSelectedIcon: false,
    );
  }
}
