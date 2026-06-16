// Экран восстановления пароля: два шага — запрос кода → ввод кода + нового пароля.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/api/api_client.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _step2 = false; // false = ввод email, true = ввод кода+пароля
  bool _loading = false;
  String? _error;
  String? _devCode; // показываем в dev-режиме

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final code = await ref.read(apiClientProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() { _step2 = true; _devCode = code; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to send code. Check your email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (code.length != 6 || pw.length < 8) {
      setState(() => _error = 'Enter 6-digit code and password (min 8 chars)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).resetPassword(
        email: _emailCtrl.text.trim(),
        code: code,
        newPassword: pw,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated! Please sign in.')),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Invalid or expired code.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_step2) ...[
              Text('Enter your email', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                "We'll send you a 6-digit code to reset your password.",
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _requestCode(),
              ),
            ] else ...[
              Text('Enter the code', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Check your email for a 6-digit code.',
                style: textTheme.bodyMedium,
              ),
              if (_devCode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DEV: code is $_devCode',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (min 8 chars)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _resetPassword(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: _step2 ? _resetPassword : _requestCode,
                    child: Text(_step2 ? 'Reset password' : 'Send code'),
                  ),
          ],
        ),
      ),
    );
  }
}
