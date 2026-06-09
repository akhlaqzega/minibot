import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cyberpunk / Dark SCADA Palette (seragam dengan LoginScreen)
// ─────────────────────────────────────────────────────────────────────────────
const _bgDeep    = Color(0xFF0D0E15);
const _bgCard    = Color(0xFF12131E);
const _bgField   = Color(0xFF1A1B2E);
const _neonBlue  = Color(0xFF00D4FF);
const _neonGreen = Color(0xFF00FF9C);
const _neonRed   = Color(0xFFFF2D55);
const _dimText   = Color(0xFF6E7191);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController     = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController  = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading  = false;
  bool _isObscure  = true;
  bool _isObscure2 = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Handle Register ────────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final user = await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      if (user != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "✓ Pendaftaran berhasil! Silakan login.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _neonGreen.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = AuthService.translateError(e.code));
    } catch (_) {
      setState(() => _errorMessage = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _neonBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _neonBlue.withValues(alpha: 0.3), width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: _neonBlue, size: 18),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: _neonBlue.withValues(alpha: 0.2)),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── HEADER ─────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _neonGreen.withValues(alpha: 0.08),
                              border: Border.all(
                                  color: _neonGreen.withValues(alpha: 0.4),
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonGreen.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person_add_rounded,
                                color: _neonGreen, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "BUAT AKUN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Daftarkan operator baru ke sistem",
                                style: TextStyle(
                                    color: _dimText, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      // ── SECTION LABEL ──────────────────────────────────
                      _sectionLabel("DATA AKUN BARU"),
                      const SizedBox(height: 16),

                      // ── NAMA LENGKAP ───────────────────────────────────
                      _buildTextField(
                        controller: _nameController,
                        label:      "Nama Lengkap",
                        icon:       Icons.badge_outlined,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── EMAIL ──────────────────────────────────────────
                      _buildTextField(
                        controller:   _emailController,
                        label:        "Email Address",
                        icon:         Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Email tidak boleh kosong';
                          }
                          if (!v.contains('@')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── PASSWORD ───────────────────────────────────────
                      _buildTextField(
                        controller: _passwordController,
                        label:      "Password",
                        icon:       Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureToggle: () =>
                            setState(() => _isObscure = !_isObscure),
                        isObscure: _isObscure,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password tidak boleh kosong';
                          }
                          if (v.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── KONFIRMASI PASSWORD ────────────────────────────
                      _buildTextField(
                        controller: _confirmController,
                        label:      "Konfirmasi Password",
                        icon:       Icons.lock_reset_rounded,
                        isPassword: true,
                        obscureToggle: () =>
                            setState(() => _isObscure2 = !_isObscure2),
                        isObscure: _isObscure2,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Konfirmasi password tidak boleh kosong';
                          }
                          if (v != _passwordController.text) {
                            return 'Password tidak sama';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── ERROR MESSAGE ──────────────────────────────────
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _neonRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _neonRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: _neonRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: _neonRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── TOMBOL DAFTAR ──────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _neonGreen.withValues(alpha: 0.15),
                            foregroundColor: _neonGreen,
                            side: BorderSide(
                                color: _neonGreen.withValues(alpha: 0.5),
                                width: 1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: _neonGreen, strokeWidth: 2),
                                )
                              : const Icon(Icons.how_to_reg_rounded,
                                  size: 20),
                          label: Text(
                            _isLoading ? "Memproses..." : "Daftar Sekarang",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── SUDAH PUNYA AKUN ───────────────────────────────
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Sudah punya akun? ",
                              style: TextStyle(
                                  color: _dimText, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                "Masuk Disini",
                                style: TextStyle(
                                  color: _neonBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _neonGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _dimText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isObscure  = false,
    VoidCallback? obscureToggle,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      obscureText:  isPassword ? isObscure : false,
      keyboardType: keyboardType,
      validator:    validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _neonBlue,
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: _dimText, fontSize: 13),
        prefixIcon: Icon(icon,
            color: _neonBlue.withValues(alpha: 0.7), size: 20),
        suffixIcon: isPassword && obscureToggle != null
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _dimText,
                  size: 20,
                ),
                onPressed: obscureToggle,
              )
            : null,
        filled:         true,
        fillColor:      _bgField,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonBlue, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonRed, width: 1.2),
        ),
        errorStyle: const TextStyle(color: _neonRed, fontSize: 11),
      ),
    );
  }
}