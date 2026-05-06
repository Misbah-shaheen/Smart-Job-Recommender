// screens/profile_screen.dart
// Users manage skills, experience, preferred role — saved to Firestore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_provider.dart';
import '../models/user_profile_model.dart';
import '../utils/app_theme.dart';

class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key});

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _skillInputCtrl = TextEditingController();

  List<String> _skills = [];
  bool _saving = false;
  bool _initialized = false;

  static const List<String> _suggestedSkills = [
    'Flutter', 'Dart', 'Python', 'Firebase', 'REST API',
    'Machine Learning', 'TensorFlow', 'React', 'Node.js',
    'Docker', 'Kubernetes', 'AWS', 'SQL', 'MongoDB',
    'Java', 'Kotlin', 'Swift', 'TypeScript', 'Git', 'Linux',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final profile = context.read<AppProvider>().profile;
      if (profile != null) {
        _nameCtrl.text = profile.name;
        _expCtrl.text = profile.experience.toString();
        _roleCtrl.text = profile.preferredRole;
        _skills = List.from(profile.skills);
      }
    }
  }

  void _addSkill(String skill) {
    final s = skill.trim();
    if (s.isEmpty) return;
    if (_skills.map((e) => e.toLowerCase()).contains(s.toLowerCase())) return;
    setState(() => _skills.add(s));
    _skillInputCtrl.clear();
  }

  void _removeSkill(String skill) =>
      setState(() => _skills.remove(skill));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final provider = context.read<AppProvider>();
    final uid = provider.user!.uid;
    final email = provider.user!.email ?? '';

    final updated = UserProfileModel(
      uid: uid,
      email: email,
      name: _nameCtrl.text.trim(),
      skills: _skills,
      experience: int.tryParse(_expCtrl.text.trim()) ?? 0,
      preferredRole: _roleCtrl.text.trim(),
    );

    await provider.saveProfile(updated);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _expCtrl.dispose();
    _roleCtrl.dispose();
    _skillInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + email ────────────────────────────────────
            const _ProfileHeader(),
            const SizedBox(height: 24),

            // ── Basic info card ───────────────────────────────────
            _Card(
              title: 'Basic Information',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _roleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preferred Job Role',
                      prefixIcon: Icon(Icons.work_outline),
                      hintText: 'e.g. Flutter Developer',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _expCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Years of Experience',
                      prefixIcon: Icon(Icons.history_edu_outlined),
                      suffixText: 'years',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (int.tryParse(v) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Skills card ───────────────────────────────────────
            _Card(
              title: 'My Skills (${_skills.length})',
              icon: Icons.psychology_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add skill input
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _skillInputCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Add a skill',
                            prefixIcon: Icon(Icons.add_circle_outline),
                            hintText: 'e.g. Flutter',
                          ),
                          onFieldSubmitted: _addSkill,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _addSkill(_skillInputCtrl.text),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 50),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Current skills chips
                  if (_skills.isNotEmpty) ...[
                    Text(
                      'Your skills:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _skills
                          .map((s) => Chip(
                        label: Text(s),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeSkill(s),
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.primary,
                        ),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Suggested skills
                  Text(
                    'Suggested skills — tap to add:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _suggestedSkills
                        .where((s) => !_skills
                        .map((e) => e.toLowerCase())
                        .contains(s.toLowerCase()))
                        .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: () => _addSkill(s),
                      avatar: const Icon(Icons.add, size: 14),
                      backgroundColor: const Color(0xFFF0F0F0),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ───────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save Profile'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppTheme.primary,
          child: Text(
            (user?.email?.isNotEmpty == true)
                ? user!.email![0].toUpperCase()
                : 'U',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.email ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Edit your professional profile',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

// Legacy alias
typedef ProfileScreen = ProfileBody;