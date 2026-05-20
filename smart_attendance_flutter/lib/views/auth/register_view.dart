import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _regNumCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _role = 'student';
  String? _serverWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final warning = await context.read<AuthController>().checkServerHealth();
      if (mounted && warning != null) {
        setState(() => _serverWarning = warning);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _firstNameCtrl.dispose();
    _lastNameCtrl.dispose(); _regNumCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.register(
      email: _emailCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      registrationNumber: _regNumCtrl.text.trim(),
      role: _role,
      password: _passwordCtrl.text,
      passwordConfirm: _confirmCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Registration successful! Please login.'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else {
      _showErrorDialog(context, auth.error ?? 'Registration failed');
    }
  }

  void _showErrorDialog(BuildContext context, String errorMsg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 28),
            SizedBox(width: 12),
            Text('Registration Failed', style: TextStyle(color: AppTheme.error)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: SelectableText(
                  errorMsg,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 Debug Info:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'Email: ${_emailCtrl.text.trim()}\n'
                      'Registration #: ${_regNumCtrl.text.trim()}\n'
                      'Role: $_role\n\n'
                      'Check the terminal output for detailed error information.',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header illustration
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.school, color: Colors.white, size: 36),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Join Smart Attendance',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('NAHPI · University of Bamenda',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_serverWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warning, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _serverWarning!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Form card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Account Type',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _RoleChip(
                          label: 'Student',
                          icon: Icons.person,
                          selected: _role == 'student',
                          onTap: () => setState(() => _role = 'student'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _RoleChip(
                          label: 'Lecturer',
                          icon: Icons.cast_for_education,
                          selected: _role == 'lecturer',
                          onTap: () => setState(() => _role = 'lecturer'),
                        )),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: AppTextField(
                          label: 'First Name',
                          controller: _firstNameCtrl,
                          prefixIcon: const Icon(Icons.person_outline),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: AppTextField(
                          label: 'Last Name',
                          controller: _lastNameCtrl,
                          prefixIcon: const Icon(Icons.person_outline),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Email Address',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Registration Number',
                      hint: 'e.g. UBa25EP188',
                      controller: _regNumCtrl,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordCtrl,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (v) => v == null || v.length < 8
                          ? 'Minimum 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Confirm Password',
                      controller: _confirmCtrl,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (v) => v != _passwordCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label: 'Create Account',
                      onPressed: auth.status == AuthStatus.loading ? null : _register,
                      isLoading: auth.status == AuthStatus.loading,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
