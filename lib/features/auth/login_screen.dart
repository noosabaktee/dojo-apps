import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../state/app_session.dart';
import '../../widgets/common.dart';
import '../../widgets/dojo_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      await showAppAlert(
        context,
        title: 'Data login belum lengkap',
        message: 'Periksa kembali email dan password yang kamu masukkan.',
      );
      return;
    }
    final success = await widget.session.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!success && mounted) {
      await showAppAlert(
        context,
        title: 'Belum bisa masuk',
        message:
            widget.session.error ??
            'Email atau password belum sesuai. Silakan coba lagi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppPageBackground(
        variant: 2,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          child: Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1C00391F),
                                  blurRadius: 26,
                                  offset: Offset(0, 13),
                                ),
                              ],
                            ),
                            child: const DojoLogoMark(size: 70),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Selamat datang',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Masuk ke Dojo untuk melanjutkan aktivitasmu.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 25),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1017221C),
                                blurRadius: 24,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'nama@email.com',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return 'Email wajib diisi.';
                                    }
                                    if (!email.contains('@')) {
                                      return 'Format email belum benar.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 13),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) => (value?.isEmpty ?? true)
                                      ? 'Password wajib diisi.'
                                      : null,
                                ),
                                const SizedBox(height: 18),
                                AnimatedBuilder(
                                  animation: widget.session,
                                  builder: (context, _) => SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: widget.session.isSubmitting
                                          ? null
                                          : _submit,
                                      icon: widget.session.isSubmitting
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.login_rounded,
                                              size: 20,
                                            ),
                                      label: Text(
                                        widget.session.isSubmitting
                                            ? 'Memeriksa...'
                                            : 'Masuk',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LoginBenefit(
                              icon: Icons.verified_user_outlined,
                              label: 'Aman',
                            ),
                            SizedBox(width: 18),
                            _LoginBenefit(
                              icon: Icons.bolt_outlined,
                              label: 'Praktis',
                            ),
                            SizedBox(width: 18),
                            _LoginBenefit(
                              icon: Icons.sync_rounded,
                              label: 'Terhubung',
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _LoginBenefit extends StatelessWidget {
  const _LoginBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.primary, size: 17),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
