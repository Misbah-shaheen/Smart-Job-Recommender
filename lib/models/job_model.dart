// models/job_model.dart
// Reads fields from Kaggle job dataset JSON (job_descriptions.csv converted).
// Dataset columns include: Job Id, Experience, Qualifications, Salary Range,
// Location, Country, Work Type, Company Size, Job Title, Role, Skills,
// Job Description, Benefits, Responsibilities, Company Name, Company Profile.

class JobModel {
  final int    id;
  final String jobTitle;
  final List<String> skills;
  final int    salary;
  final int    experience;
  final String workType;      // 'Remote' | 'Hybrid' | 'Onsite'
  final String description;
  final double? matchPercentage;

  // Dataset fields
  final String company;
  final String location;
  final String qualifications;
  final String companySize;

  const JobModel({
    required this.id,
    required this.jobTitle,
    required this.skills,
    required this.salary,
    required this.experience,
    required this.workType,
    required this.description,
    this.matchPercentage,
    this.company        = 'Unknown Company',
    this.location       = '',
    this.qualifications = "Bachelor's Degree",
    this.companySize    = 'Medium',
  });

  // ── Backward-compat getters ──────────────────────────────────
  int get salaryMin => (salary * 0.85).round();
  int get salaryMax => (salary * 1.15).round();

  factory JobModel.fromJson(Map<String, dynamic> json) {
    // ── Skills ────────────────────────────────────────────────
    final skillList = (json['skills'] ?? json['Skills'] ?? '')
        .toString()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // ── ID ────────────────────────────────────────────────────
    // Kaggle uses "Job Id" column
    final idRaw = json['id'] ?? json['job_id'] ?? json['Job Id'] ??
        json['job Id'] ?? json['jobId'] ?? 0;
    final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;

    // ── Salary ───────────────────────────────────────────────
    // Dataset has "Salary Range" like "$80,000 - $120,000" or "80000-120000"
    int salary = 0;
    final salaryRaw = json['salary'] ?? json['salary_range'] ??
        json['Salary Range'] ?? json['salary_range_usd'] ?? 0;
    final salaryStr = salaryRaw.toString()
        .replaceAll(r'$', '').replaceAll(',', '').trim();
    if (salaryStr.contains('-')) {
      final parts = salaryStr.split('-');
      final lo = int.tryParse(parts[0].trim()) ?? 0;
      final hi = int.tryParse(parts[1].trim()) ?? 0;
      salary = lo > 0 || hi > 0 ? ((lo + hi) / 2).round() : 0;
    } else {
      salary = int.tryParse(salaryStr) ?? 0;
    }

    // ── Experience ───────────────────────────────────────────
    // Dataset "Experience" may be "3 Years" or "3-5 Years" or just "3"
    int experience = 0;
    final expRaw = json['experience'] ?? json['Experience'] ?? 0;
    if (expRaw is int) {
      experience = expRaw;
    } else {
      final m = RegExp(r'\d+').firstMatch(expRaw.toString());
      experience = m != null ? int.parse(m.group(0)!) : 0;
    }

    // ── Work Type ────────────────────────────────────────────
    // Dataset "Work Type" = Full-Time / Part-Time / Contract / Temporary / Internship
    // Normalise to Remote / Hybrid / Onsite for the app's filter system.
    final rawWt = (json['work_type'] ?? json['Work Type'] ??
        json['workType']  ?? '').toString().trim();
    final workType = _normaliseWorkType(rawWt, id);

    // ── Company Name ─────────────────────────────────────────
    // Kaggle dataset column is "Company Name".  Python pandas to_json()
    // keeps spaces in keys, so try both spaced and underscored forms.
    final company = _readField(json, [
      'Company Name', 'company_name', 'company', 'Company',
      'employer', 'Employer', 'organization', 'Organization',
    ]);

    // ── Other fields ─────────────────────────────────────────
    final location = _readField(json, ['location', 'Location', 'city', 'City']);
    final qualifications = _readField(json, [
      'qualifications', 'Qualifications', 'qualification',
      'education', 'Education',
    ], fallback: "Bachelor's Degree");
    final companySize = _readField(json, [
      'company_size', 'Company Size', 'companySize', 'size',
    ], fallback: 'Medium');
    final description = _readField(json, [
      'description', 'job_description', 'Job Description',
      'jobDescription', 'responsibilities', 'Responsibilities',
    ]);

    // ── Job Title ─────────────────────────────────────────────
    final jobTitle = _readField(json, [
      'job_title', 'Job Title', 'jobTitle', 'title', 'Title', 'role', 'Role',
    ]);

    return JobModel(
      id:             id,
      jobTitle:       jobTitle,
      skills:         skillList as List<String>,
      salary:         salary,
      experience:     experience,
      workType:       workType,
      description:    description,
      matchPercentage: json['match_percentage'] != null
          ? double.tryParse(json['match_percentage'].toString())
          : null,
      company:        company,
      location:       location,
      qualifications: qualifications,
      companySize:    companySize,
    );
  }

  // ── Read a field trying multiple possible key names ─────────
  static String _readField(
      Map<String, dynamic> json,
      List<String> keys, {
        String fallback = '',
      }) {
    for (final key in keys) {
      final val = json[key]?.toString().trim() ?? '';
      if (val.isNotEmpty &&
          val != 'null' && val != 'nan' &&
          val != 'N/A'  && val != 'Unknown Company') {
        return val;
      }
    }
    return fallback;
  }

  // ── Normalise employment type -> Remote / Hybrid / Onsite ───
  static String _normaliseWorkType(String raw, int id) {
    final v = raw.toLowerCase().trim();
    if (v == 'remote')                        return 'Remote';
    if (v == 'hybrid')                        return 'Hybrid';
    if (v == 'onsite' || v == 'on-site')      return 'Onsite';
    if (v.contains('full'))  { final r = id % 10; return r < 2 ? 'Remote' : r < 5 ? 'Hybrid' : 'Onsite'; }
    if (v.contains('contract')) { final r = id % 5; return r < 2 ? 'Remote' : r < 4 ? 'Hybrid' : 'Onsite'; }
    if (v.contains('part'))  { final r = id % 10; return r < 6 ? 'Remote' : r < 9 ? 'Hybrid' : 'Onsite'; }
    if (v.contains('temp'))  { final r = id % 3; return r == 0 ? 'Remote' : r == 1 ? 'Hybrid' : 'Onsite'; }
    if (v.contains('intern'))                 return 'Onsite';
    const t = ['Remote', 'Hybrid', 'Onsite'];
    return t[id % 3];
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'job_title':      jobTitle,
    'skills':         skills.join(','),
    'salary':         salary,
    'experience':     experience,
    'work_type':      workType,
    'description':    description,
    if (matchPercentage != null) 'match_percentage': matchPercentage,
    'company':        company,
    'location':       location,
    'qualifications': qualifications,
    'company_size':   companySize,
  };

  JobModel copyWithMatch(double match) => JobModel(
    id: id, jobTitle: jobTitle, skills: skills, salary: salary,
    experience: experience, workType: workType, description: description,
    matchPercentage: match, company: company, location: location,
    qualifications: qualifications, companySize: companySize,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is JobModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}