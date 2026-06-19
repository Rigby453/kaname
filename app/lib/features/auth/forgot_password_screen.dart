// Экран восстановления пароля: два шага — запрос кода → ввод кода + нового пароля.
//
// Редизайн (design-kai): KaiLoader вместо CircularProgressIndicator,
// ошибки через ember, themed InputDecoration (без ручных border-оверрайдов),
// FilledButton — единственная primary-кнопка, TextButton «назад».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await ref.read(apiClientProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _step2 = true;
        _devCode = code;
      });
    } catch (e) {
      if (mounted) setState(() => _error = context.s('auth.reset_err_send'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (code.length != 6 || pw.length < 8) {
      setState(() => _error = context.s('auth.reset_err_code_pw'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).resetPassword(
            email: _emailCtrl.text.trim(),
            code: code,
            newPassword: pw,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('auth.reset_success_snack'))),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = context.s('auth.reset_err_invalid_code'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      // AppBar без кастомных стилей — тема уже настроена
      appBar: AppBar(title: Text(context.s('auth.reset_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Заголовок шага: headlineSmall ---
              Text(
                _step2
                    ? context.s('auth.reset_step2_heading')
                    : context.s('auth.reset_step1_heading'),
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),

              // --- Описание шага: bodyLarge, textMuted ---
              Text(
                _step2
                    ? context.s('auth.reset_step2_body')
                    : context.s('auth.reset_step1_body'),
                style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
              ),

              // --- DEV-код (debug banner) ---
              if (_step2 && _devCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // surfaceElevated для вторичных элементов (не accent, не bg)
                    color: ext.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ext.border),
                  ),
                  child: Text(
                    'DEV: code is $_devCode',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // --- Поля ввода (без ручного border-оверрайда) ---
              if (!_step2) ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: context.s('auth.field_email'),
                  ),
                  onSubmitted: _loading ? null : (_) => _requestCode(),
                ),
              ] else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: context.s('auth.reset_field_code'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pwCtrl,
                  obscureText: true,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: context.s('auth.reset_field_new_password'),
                  ),
                  onSubmitted: _loading ? null : (_) => _resetPassword(),
                ),
              ],

              // --- Ошибка: ember (urgent/error color) ---
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: ext.ember),
                ),
              ],

              const SizedBox(height: 28),

              // --- Loading: KaiLoader вместо CircularProgressIndicator ---
              if (_loading)
                const Center(
                  child: KaiLoader(size: 48),
                )
              else ...[
                // Primary action: единственный FilledButton
                FilledButton(
                  onPressed: _step2 ? _resetPassword : _requestCode,
                  child: Text(
                    _step2
                        ? context.s('auth.reset_btn_reset')
                        : context.s('auth.reset_btn_send_code'),
                  ),
                ),

                // Step 2: TextButton чтобы вернуться к вводу email
                if (_step2) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() {
                      _step2 = false;
                      _error = null;
                      _devCode = null;
                    }),
                    child: Text(
                      context.s('auth.reset_change_email'),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
