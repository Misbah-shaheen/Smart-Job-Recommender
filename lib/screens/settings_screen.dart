// screens/settings_screen.dart
// ix. Settings — customize notifications, security, display, and app preferences.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';

class SettingsBody extends StatefulWidget {
  const SettingsBody({super.key});

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // ── Notification prefs ──────────────────────────────────────────────
  bool _notifJobs = true;
  bool _notifTrending = true;
  bool _notifRecommendations = true;
  bool _notifInsights = false;

  // ── Display prefs ────────────────────────────────────────────────────
  bool _darkMode = false;
  bool _compactCards = false;
  String _accentColor = 'Purple';

  // ── Security ─────────────────────────────────────────────────────────
  bool _biometrics = false;
  bool _rememberLogin = true;

  // ── App ───────────────────────────────────────────────────────────────
  bool _autoRefresh = true;
  String _defaultTab = 'Search';

  static const String _kNotifJobs = 'notif_jobs';
  static const String _kNotifTrend = 'notif_trending';
  static const String _kNotifRec = 'notif_rec';
  static const String _kNotifIns = 'notif_insights';
  static const String _kCompact = 'compact_cards';
  static const String _kBiometrics = 'biometrics';
  static const String _kRemember = 'remember_login';
  static const String _kAutoRefresh = 'auto_refresh';
  static const String _kDefaultTab = 'default_tab';
  static const String _kAccent = 'accent_color';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadPrefs();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifJobs = prefs.getBool(_kNotifJobs) ?? true;
      _notifTrending = prefs.getBool(_kNotifTrend) ?? true;
      _notifRecommendations = prefs.getBool(_kNotifRec) ?? true;
      _notifInsights = prefs.getBool(_kNotifIns) ?? false;
      _compactCards = prefs.getBool(_kCompact) ?? false;
      _biometrics = prefs.getBool(_kBiometrics) ?? false;
      _rememberLogin = prefs.getBool(_kRemember) ?? true;
      _autoRefresh = prefs.getBool(_kAutoRefresh) ?? true;
      _defaultTab = prefs.getString(_kDefaultTab) ?? 'Search';
      _accentColor = prefs.getString(_kAccent) ?? 'Purple';
    });
    _ctrl.forward();
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showAccentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccentColorSheet(
        current: _accentColor,
        onSelect: (c) {
          setState(() => _accentColor = c);
          _save(_kAccent, c);
        },
      ),
    );
  }

  void _showDefaultTabPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: 'Default Tab',
        options: const ['Search', 'For You', 'Trending', 'Insights'],
        current: _defaultTab,
        onSelect: (t) {
          setState(() => _defaultTab = t);
          _save(_kDefaultTab, t);
        },
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You\'ll need to sign in again to access your personalized data.',
          style: GoogleFonts.inter(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppProvider>().signOut();
    }
  }

  Future<void> _clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Local data cleared',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _loadPrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeader(),
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) => Opacity(
              opacity: _ctrl.value,
              child: child,
            ),
            child: Column(
              children: [
                _buildSection(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  color: const Color(0xFF6C63FF),
                  children: [
                    _ToggleTile(
                      label: 'Job Alerts',
                      subtitle: 'New jobs matching your skills',
                      value: _notifJobs,
                      onChanged: (v) {
                        setState(() => _notifJobs = v);
                        _save(_kNotifJobs, v);
                      },
                    ),
                    _ToggleTile(
                      label: 'Trending Skills',
                      subtitle: 'Weekly skill demand updates',
                      value: _notifTrending,
                      onChanged: (v) {
                        setState(() => _notifTrending = v);
                        _save(_kNotifTrend, v);
                      },
                    ),
                    _ToggleTile(
                      label: 'Recommendations',
                      subtitle: 'AI-curated picks for you',
                      value: _notifRecommendations,
                      onChanged: (v) {
                        setState(() => _notifRecommendations = v);
                        _save(_kNotifRec, v);
                      },
                    ),
                    _ToggleTile(
                      label: 'Career Insights',
                      subtitle: 'Market trend alerts',
                      value: _notifInsights,
                      onChanged: (v) {
                        setState(() => _notifInsights = v);
                        _save(_kNotifIns, v);
                      },
                    ),
                  ],
                ),
                _buildSection(
                  icon: Icons.palette_outlined,
                  title: 'Display',
                  color: const Color(0xFF48CAE4),
                  children: [
                    _ToggleTile(
                      label: 'Compact Job Cards',
                      subtitle: 'Show more jobs per screen',
                      value: _compactCards,
                      onChanged: (v) {
                        setState(() => _compactCards = v);
                        _save(_kCompact, v);
                      },
                    ),
                    _TapTile(
                      label: 'Accent Color',
                      subtitle: _accentColor,
                      trailing: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _accentColorValue(_accentColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      onTap: _showAccentPicker,
                    ),
                    _TapTile(
                      label: 'Default Tab',
                      subtitle: _defaultTab,
                      onTap: _showDefaultTabPicker,
                    ),
                  ],
                ),
                _buildSection(
                  icon: Icons.shield_outlined,
                  title: 'Security',
                  color: const Color(0xFF6BCB77),
                  children: [
                    _ToggleTile(
                      label: 'Remember Login',
                      subtitle: 'Stay signed in between sessions',
                      value: _rememberLogin,
                      onChanged: (v) {
                        setState(() => _rememberLogin = v);
                        _save(_kRemember, v);
                      },
                    ),
                    _ToggleTile(
                      label: 'Biometric Auth',
                      subtitle: 'Use fingerprint or face unlock',
                      value: _biometrics,
                      onChanged: (v) {
                        setState(() => _biometrics = v);
                        _save(_kBiometrics, v);
                      },
                    ),
                  ],
                ),
                _buildSection(
                  icon: Icons.tune_outlined,
                  title: 'App Preferences',
                  color: const Color(0xFFFFD93D),
                  children: [
                    _ToggleTile(
                      label: 'Auto-Refresh Jobs',
                      subtitle: 'Reload job list on app open',
                      value: _autoRefresh,
                      onChanged: (v) {
                        setState(() => _autoRefresh = v);
                        _save(_kAutoRefresh, v);
                      },
                    ),
                  ],
                ),
                _buildSection(
                  icon: Icons.info_outline,
                  title: 'Account & Data',
                  color: const Color(0xFFFF6B6B),
                  children: [
                    _TapTile(
                      label: 'Clear Local Data',
                      subtitle: 'Reset cached notifications & prefs',
                      textColor: const Color(0xFFFF922B),
                      onTap: _clearData,
                    ),
                    _TapTile(
                      label: 'Sign Out',
                      subtitle: context.read<AppProvider>().user?.email ?? '',
                      textColor: const Color(0xFFFF6B6B),
                      onTap: _confirmSignOut,
                    ),
                  ],
                ),
                _buildVersion(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A3E), Color(0xFF0D0D1A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Customize your experience',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13132B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: children
                  .asMap()
                  .entries
                  .map((e) => Column(
                children: [
                  e.value,
                  if (e.key < children.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersion() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.work_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Smart Job Recommender',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'Version 1.0.0',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Color _accentColorValue(String name) {
    switch (name) {
      case 'Purple':
        return const Color(0xFF6C63FF);
      case 'Cyan':
        return const Color(0xFF48CAE4);
      case 'Green':
        return const Color(0xFF6BCB77);
      case 'Orange':
        return const Color(0xFFFF922B);
      case 'Pink':
        return const Color(0xFFF472B6);
      default:
        return const Color(0xFF6C63FF);
    }
  }
}

// ─── Reusable setting tiles ────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6C63FF),
            activeTrackColor: const Color(0xFF6C63FF).withOpacity(0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white.withOpacity(0.08),
          ),
        ],
      ),
    );
  }
}

class _TapTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget? trailing;
  final Color? textColor;
  final VoidCallback onTap;

  const _TapTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? Colors.white,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheets ─────────────────────────────────────────────────────────────

class _AccentColorSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _AccentColorSheet({required this.current, required this.onSelect});

  static const colors = {
    'Purple': Color(0xFF6C63FF),
    'Cyan': Color(0xFF48CAE4),
    'Green': Color(0xFF6BCB77),
    'Orange': Color(0xFFFF922B),
    'Pink': Color(0xFFF472B6),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Accent Color',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            children: colors.entries.map((e) {
              final isSelected = e.key == current;
              return GestureDetector(
                onTap: () {
                  onSelect(e.key);
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: e.value.withOpacity(0.5),
                            blurRadius: isSelected ? 12 : 4,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.key,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OptionSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String current;
  final ValueChanged<String> onSelect;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final selected = opt == current;
            return ListTile(
              title: Text(
                opt,
                style: GoogleFonts.inter(
                  color: selected ? const Color(0xFF6C63FF) : Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check, color: Color(0xFF6C63FF))
                  : null,
              onTap: () {
                onSelect(opt);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Legacy alias
typedef SettingsScreen = SettingsBody;