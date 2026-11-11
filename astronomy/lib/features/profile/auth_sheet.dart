import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/auth_service.dart';

/// Opens the email sign-in / create-account sheet. Resolves to true on success.
Future<bool> showEmailAuthSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _EmailAuthSheet(),
  );
  return ok ?? false;
}

class _EmailAuthSheet extends ConsumerStatefulWidget {
  const _EmailAuthSheet();

  @override
  ConsumerState<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends ConsumerState<_EmailAuthSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Sets the busy flag and message together; clears the other message.
  void _update({bool busy = false, String? error, String? info}) {
    if (!mounted) return;
    setState(() {
      _busy = busy;
      _error = error;
      _info = info;
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    _update(busy: true);
    final auth = ref.read(authServiceProvider);
    try {
      if (_register) {
        await auth.registerWithEmail(_name.text, _email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      _update(error: e.message);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    _update(busy: true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      _update(info: 'Reset link sent to $email.');
    } on AuthFailure catch (e) {
      _update(error: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.surfaceBorderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text(_register ? 'Create your account' : 'Sign in with email', style: AppText.section),
            const SizedBox(height: 4),
            Text(
              'Your saved objects, settings and home spot follow you to any device.',
              style: AppText.body(13, color: AppColors.textSoft),
            ),
            const SizedBox(height: 18),
            if (_register) ...[
              _Field(
                controller: _name,
                label: 'Name',
                icon: AppIcons.user,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
            ],
            _Field(
              controller: _email,
              label: 'Email',
              icon: AppIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _password,
              label: 'Password',
              icon: AppIcons.lock,
              obscure: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
              onSubmitted: (_) => _submit(),
              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              suffix: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                icon: Icon(_showPassword ? AppIcons.eyeOff : AppIcons.eye, size: 20, color: AppColors.textMuted),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            if (_error != null || _info != null) ...[
              const SizedBox(height: 12),
              Text(
                _error ?? _info!,
                style: AppText.body(13, color: _error != null ? AppColors.red : AppColors.cyan),
              ),
            ],
            const SizedBox(height: 18),
            GradientButton(
              label: _busy ? 'Please wait…' : (_register ? 'Create account' : 'Sign in'),
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: _busy ? null : () => setState(() {
                  _register = !_register;
                  _error = _info = null;
                }),
                child: Text(_register ? 'I have an account' : 'Create an account',
                    style: AppText.body(14, weight: FontWeight.w600, color: AppColors.cyan)),
              ),
              if (!_register)
                TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: Text('Forgot password?', style: AppText.body(14, color: AppColors.textSoft)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c));
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      style: AppText.body(15),
      cursorColor: AppColors.cyan,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(14, color: AppColors.textMuted),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: border(AppColors.inputBorder),
        focusedBorder: border(AppColors.cyan),
        errorBorder: border(AppColors.red),
        focusedErrorBorder: border(AppColors.red),
        errorStyle: AppText.body(12, color: AppColors.red),
      ),
    );
  }
}
