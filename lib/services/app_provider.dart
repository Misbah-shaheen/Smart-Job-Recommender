// services/app_provider.dart
// Single ChangeNotifier that holds all shared state.
//
// PERFORMANCE FIX:
// The original code called loadJobs() immediately inside the Firebase auth
// listener. This meant 25,000 jobs were being parsed + scored synchronously
// at startup, BEFORE the UI even appeared → "Skipped 410 frames" → emulator
// killed the app ("Lost connection to device").
//
// Fix: jobs are now loaded LAZILY — only when a screen actually needs them.
// loadJobsIfNeeded() is idempotent (safe to call multiple times) and skips
// the load if jobs are already cached.

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile_model.dart';
import '../models/job_model.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'job_service.dart';

class AppProvider extends ChangeNotifier {
  // ─── Services ────────────────────────────────────────────────────────
  final AuthService    _authService    = AuthService();
  final ProfileService _profileService = ProfileService();
  final JobService     _jobService     = JobService();

  // ─── Auth state ──────────────────────────────────────────────────────
  User? _user;
  User? get user      => _user;
  bool  get isLoggedIn => _user != null;

  // ─── Profile ─────────────────────────────────────────────────────────
  UserProfileModel? _profile;
  UserProfileModel? get profile => _profile;

  // ─── Jobs ─────────────────────────────────────────────────────────────
  List<JobModel> _filteredJobs    = [];
  List<JobModel> get filteredJobs => _filteredJobs;

  List<JobModel> _recommendations    = [];
  List<JobModel> get recommendations => _recommendations;

  // ─── Loading flags ────────────────────────────────────────────────────
  bool _loadingJobs = false;
  bool _loadingRec  = false;
  bool get loadingJobs => _loadingJobs;
  bool get loadingRec  => _loadingRec;

  // FIX: track whether first load has happened so we don't reload every time
  bool _jobsLoaded = false;

  String? _error;
  String? get error => _error;

  // ─── Search state ─────────────────────────────────────────────────────
  String  _lastQuery       = '';
  String? _lastWorkType;
  int?    _lastMaxSalary;
  int?    _lastMaxExperience;
  String  get lastQuery    => _lastQuery;

  // ─── INIT ─────────────────────────────────────────────────────────────
  // FIX: Only load profile on auth change — DO NOT load jobs here.
  // Jobs are loaded lazily by loadJobsIfNeeded() when a screen opens.
  AppProvider() {
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await _loadProfile(user.uid);
        // REMOVED: await loadJobs() ← this was the startup freeze culprit
      } else {
        _profile      = null;
        _filteredJobs = [];
        _jobsLoaded   = false;
      }
      notifyListeners();
    });
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────
  Future<void> signIn(String email, String password) async {
    final cred = await _authService.signIn(email: email, password: password);
    _user = cred.user;
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    final cred = await _authService.signUp(email: email, password: password);
    _user = cred.user;
    final emptyProfile = UserProfileModel.empty(cred.user!.uid, email);
    await _profileService.saveProfile(emptyProfile);
    _profile = emptyProfile;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user         = null;
    _profile      = null;
    _filteredJobs = [];
    _jobsLoaded   = false;
    notifyListeners();
  }

  // ─── PROFILE ──────────────────────────────────────────────────────────
  Future<void> _loadProfile(String uid) async {
    _profile = await _profileService.getProfile(uid);
  }

  Future<void> saveProfile(UserProfileModel p) async {
    await _profileService.saveProfile(p);
    _profile = p;
    // Re-score with updated skills, but only if jobs are already loaded
    if (_jobsLoaded) {
      await loadJobs(
        query:         _lastQuery,
        workType:      _lastWorkType,
        maxSalary:     _lastMaxSalary,
        maxExperience: _lastMaxExperience,
      );
    }
    notifyListeners();
  }

  // ─── LAZY LOAD: call this from any screen that needs jobs ─────────────
  // Safe to call multiple times — only does the heavy work once.
  // Screens should call this in initState() or a FutureBuilder.
  Future<void> loadJobsIfNeeded() async {
    if (_jobsLoaded || _loadingJobs) return;
    await loadJobs();
  }

  // ─── JOBS (filter + weighted ranking) ────────────────────────────────
  Future<void> loadJobs({
    String  query         = '',
    String? workType,
    int?    maxSalary,
    int?    maxExperience,
  }) async {
    _loadingJobs = true;
    _error       = null;
    _lastQuery        = query;
    _lastWorkType     = workType;
    _lastMaxSalary    = maxSalary;
    _lastMaxExperience = maxExperience;
    notifyListeners();

    try {
      final userSkills = _profile?.skills ?? [];
      _filteredJobs = await _jobService.filterJobs(
        query:         query,
        workType:      workType,
        maxSalary:     maxSalary,
        maxExperience: maxExperience,
        userSkills:    userSkills,
      );
      _jobsLoaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingJobs = false;
      notifyListeners();
    }
  }

  // ─── ML RECOMMENDATIONS ───────────────────────────────────────────────
  Future<void> fetchRecommendations() async {
    if (_profile == null || _profile!.skills.isEmpty) {
      _error = 'Please add your skills in Profile first.';
      notifyListeners();
      return;
    }
    _loadingRec = true;
    _error      = null;
    notifyListeners();
    try {
      _recommendations = await _jobService.getRecommendations(_profile!.skills);
    } catch (e) {
      _error = 'Could not reach ML server: ${e.toString()}';
    } finally {
      _loadingRec = false;
      notifyListeners();
    }
  }

  // ─── SKILL GAP ────────────────────────────────────────────────────────
  Future<Map<String, List<String>>> fetchSkillGap(int jobId) async {
    final userSkills = _profile?.skills ?? [];
    return _jobService.getSkillGap(userSkills: userSkills, jobId: jobId);
  }

  // ─── SKILL DEMAND MAP ─────────────────────────────────────────────────
  Future<Map<String, int>> getSkillDemandMap() =>
      _jobService.getSkillDemandMap();

  // ─── ALL JOBS ─────────────────────────────────────────────────────────
  Future<List<JobModel>> loadAllJobs() => _jobService.loadAllJobs();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}