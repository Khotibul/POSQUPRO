import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

/// Layar daftar akun baru (tenant + owner) — mirror pos-next-js /register.
/// Route: /daftar (nama /register sudah dipakai layar Kas & Shift).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _agreed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _storeCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus menyetujui Syarat & Ketentuan.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameCtrl.text.trim(),
      tenantName: _storeCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  String? _required(String? v, [String msg = 'Wajib diisi']) {
    if (v == null || v.trim().isEmpty) return msg;
    return null;
  }

  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
    if (v.trim().length < 2) return 'Nama minimal 2 karakter';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
    if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid';
    return null;
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password wajib diisi';
    if (v.length < 8) return 'Password minimal 8 karakter';
    return null;
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.isEmpty) return 'Ulangi password';
    if (v != _passwordCtrl.text) return 'Password tidak sama';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.ivory)),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: _glow(AppColors.primary.withValues(alpha: 0.14), 300),
          ),
          Positioned(
            bottom: -100,
            left: -90,
            child: _glow(AppColors.secondary.withValues(alpha: 0.16), 280),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 22, vertical: 24),
                child: Container(
                  width: isDesktop ? 440 : double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white),
                    boxShadow: AppShadows.lifted,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 118,
                            height: 62,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: AppShadows.soft,
                            ),
                            child: Image.asset(
                              'assets/icon/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.point_of_sale_rounded,
                                size: 32,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'Buat Akun Baru',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'Daftarkan bisnis Anda — gratis trial 14 hari',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Container(width: 26, height: 3, decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Container(width: 8, height: 3, decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2))),
                          ],
                        ),
                        const SizedBox(height: 18),

                        const Text('Nama Lengkap', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'John Doe',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 19, color: AppColors.textMuted),
                          ),
                          validator: _nameValidator,
                        ),
                        const SizedBox(height: 14),

                        const Text('Nama Toko / Bisnis', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _storeCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Nama Toko atau Perusahaan',
                            prefixIcon: Icon(Icons.storefront_outlined, size: 19, color: AppColors.textMuted),
                          ),
                          validator: (v) => _required(v, 'Nama bisnis wajib diisi'),
                        ),
                        const SizedBox(height: 14),

                        const Text('Email', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'contoh@toko.com',
                            prefixIcon: Icon(Icons.alternate_email_rounded, size: 19, color: AppColors.textMuted),
                          ),
                          validator: _emailValidator,
                        ),
                        const SizedBox(height: 14),

                        const Text('Telepon (opsional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: '0812 3456 7890',
                            prefixIcon: Icon(Icons.phone_outlined, size: 19, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text('Password', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Min. 8 karakter',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19, color: AppColors.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: _passwordValidator,
                        ),
                        const SizedBox(height: 14),

                        const Text('Ulangi Password', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          decoration: const InputDecoration(
                            hintText: 'Masukkan ulang password',
                            prefixIcon: Icon(Icons.lock_reset_rounded, size: 19, color: AppColors.textMuted),
                          ),
                          validator: _confirmValidator,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 32,
                              child: Checkbox(
                                value: _agreed,
                                onChanged: (v) => setState(() => _agreed = v ?? false),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                                    children: [
                                      const TextSpan(text: 'Saya menyetujui '),
                                      TextSpan(
                                        text: 'Syarat & Ketentuan',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: ' serta '),
                                      TextSpan(
                                        text: 'Kebijakan Privasi',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: ' yang berlaku.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return Column(
                              children: [
                                if (auth.error != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(11),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline_rounded, size: 17, color: AppColors.danger),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            auth.error!,
                                            style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.hero,
                                      borderRadius: BorderRadius.circular(AppRadius.field),
                                      boxShadow: AppShadows.soft,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: auth.isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        disabledBackgroundColor: Colors.transparent,
                                      ),
                                      child: auth.isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text('Daftar Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_forward_rounded, size: 18),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                children: [
                                  const TextSpan(text: 'Sudah punya akun? '),
                                  TextSpan(
                                    text: 'Masuk',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.dns_rounded, size: 13, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    ApiService().baseUrl.replaceFirst(RegExp(r'^https?://'), ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
