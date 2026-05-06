from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from collections import Counter
import datetime

app = Flask(__name__)
 # Allow Flutter to call this API
CORS(app)  

# ──────────────────────────────────────────────
# LOAD DATASET AT STARTUP
# ──────────────────────────────────────────────
print("Loading jobs.json ...")
with open("jobs.json", "r", encoding="utf-8") as f:
    data = json.load(f)

jobs = data["jobs"]   # list of dicts
print(f"Loaded {len(jobs):,} jobs")

print("Building TF-IDF matrix ...")

corpus = []
for job in jobs:
    skills_text = str(job.get("skills", "")).lower()
    # Truncate description to 200 chars — reduces vocabulary explosion
    desc_text   = str(job.get("description", ""))[:200].lower()
    role_text   = str(job.get("role", "")).lower()
    corpus.append(f"{skills_text} {role_text} {desc_text}")

vectorizer = TfidfVectorizer(
    stop_words  = "english",
    ngram_range = (1, 2),     # unigrams + bigrams
    max_features= 8000,       # caps vocabulary to lower RAM
    sublinear_tf= True,       # log normalization to better scores
    min_df      = 2,          # ignore terms appearing in < 2 docs
)
tfidf_matrix = vectorizer.fit_transform(corpus)

print(f"TF-IDF matrix: {tfidf_matrix.shape[0]:,} jobs × {tfidf_matrix.shape[1]:,} features")
print("Flask is ready!\n")

# HELPERS

def preprocess_query(skills: list) -> str:
    """Normalize user skill list into a single query string."""
    cleaned = [re.sub(r"[^a-z0-9\s]", " ", s.lower()) for s in skills]
    return " ".join(cleaned)


def job_summary(job: dict, match_pct: float = None) -> dict:
    """Return a slim version of job dict for list responses."""
    out = {
        "id":           job.get("id"),
        "job_title":    job.get("job_title"),
        "company":      job.get("company"),
        "location":     job.get("location"),
        "country":      job.get("country"),
        "work_type":    job.get("work_type"),
        "salary_min":   job.get("salary_min"),
        "salary_max":   job.get("salary_max"),
        "experience":   job.get("experience"),
        "skills":       job.get("skills"),
        "role":         job.get("role"),
        "qualifications": job.get("qualifications"),
        "posting_date": job.get("posting_date"),
        "latitude":     job.get("latitude"),
        "longitude":    job.get("longitude"),
    }
    if match_pct is not None:
        out["match_percentage"] = match_pct
    return out

# POST /recommend
@app.route("/recommend", methods=["POST"])
def recommend():

    body = request.get_json(silent=True)
    if not body or "skills" not in body:
        return jsonify({"error": "Missing 'skills' field in request body"}), 400

    user_skills  = body["skills"]
    top_n        = int(body.get("top_n", 5))
    filter_wtype = body.get("work_type", "").strip().lower()
    filter_min_sal = body.get("min_salary", 0)
    filter_max_exp = body.get("max_experience", 9999)

    if not user_skills:
        return jsonify({"error": "Skills list is empty"}), 400

    # TF-IDF similarity
    query_str  = preprocess_query(user_skills)
    query_vec  = vectorizer.transform([query_str])
    sims       = cosine_similarity(query_vec, tfidf_matrix).flatten()

    # Get top candidates 
    candidate_indices = np.argsort(sims)[::-1][: top_n * 10]

    recommendations = []
    for idx in candidate_indices:
        job = jobs[idx]

        # Optional filters
        if filter_wtype and job.get("work_type", "").lower() != filter_wtype:
            continue
        if job.get("salary_min", 0) < filter_min_sal:
            continue
        if job.get("experience", 0) > filter_max_exp:
            continue

        match_pct = round(float(sims[idx]) * 100, 1)
        recommendations.append(job_summary(job, match_pct))

        if len(recommendations) >= top_n:
            break

    return jsonify({
        "recommendations": recommendations,
        "total_matched": len(recommendations),
    })


# POST /skill_gap
@app.route("/skill_gap", methods=["POST"])
def skill_gap():

    body = request.get_json(silent=True)
    if not body:
        return jsonify({"error": "Invalid JSON"}), 400

    user_skills = [s.lower().strip() for s in body.get("user_skills", [])]
    job_id      = body.get("job_id")

    job = next((j for j in jobs if j.get("id") == job_id), None)
    if not job:
        return jsonify({"error": f"Job with id={job_id} not found"}), 404

    job_skills = [s.strip() for s in str(job.get("skills", "")).split(",") if s.strip()]

    matching = [s for s in job_skills if s in user_skills]
    missing  = [s for s in job_skills if s not in user_skills]
    match_pct = round(len(matching) / len(job_skills) * 100, 1) if job_skills else 0.0

    return jsonify({
        "job_title":       job.get("job_title"),
        "matching_skills": matching,
        "missing_skills":  missing,
        "match_percentage": match_pct,
    })


# GET /job/<id>
@app.route("/job/<int:job_id>", methods=["GET"])
def get_job(job_id):
    """
    Returns the complete job record including description, benefits,
    responsibilities, company profile — everything.
    """
    job = next((j for j in jobs if j.get("id") == job_id), None)
    if not job:
        return jsonify({"error": f"Job with id={job_id} not found"}), 404
    return jsonify(job)

# GET /stats
@app.route("/stats", methods=["GET"])
def stats():
    """
    Returns aggregated statistics for dashboard graphs:
      - jobs_by_work_type     → pie chart
      - jobs_by_country       → bar chart (top 10)
      - jobs_by_role          → bar chart (top 10)
      - avg_salary_by_role    → bar chart (top 10)
      - jobs_posted_by_month  → line chart (trend over time)
      - experience_distribution → histogram
      - top_skills            → word cloud / bar chart (top 20)
    """
    # jobs by work type
    work_type_counts = Counter(j.get("work_type", "Other") for j in jobs)

    # top 10 countries 
    country_counts = Counter(j.get("country", "Unknown") for j in jobs)
    top_countries  = dict(country_counts.most_common(10))

    # top 10 roles 
    role_counts = Counter(j.get("role", "Other") for j in jobs)
    top_roles   = dict(role_counts.most_common(10))

    # avg salary by role 
    role_salaries = {}
    for j in jobs:
        role = j.get("role", "Other")
        sal  = (j.get("salary_min", 0) + j.get("salary_max", 0)) / 2
        if role not in role_salaries:
            role_salaries[role] = []
        role_salaries[role].append(sal)

    top_role_names = [r for r, _ in role_counts.most_common(10)]
    avg_salary_by_role = {
        role: round(sum(role_salaries[role]) / len(role_salaries[role]))
        for role in top_role_names
        if role in role_salaries and role_salaries[role]
    }

    # jobs posted by month 
    monthly_counts = Counter()
    for j in jobs:
        date_str = str(j.get("posting_date", ""))
        if len(date_str) >= 7:
            month_key = date_str[:7]   
            monthly_counts[month_key] += 1

    jobs_by_month = dict(sorted(monthly_counts.items()))   

    # ── experience distribution (buckets) ──
    exp_buckets = {"0-1 yrs": 0, "2-3 yrs": 0, "4-5 yrs": 0, "6-8 yrs": 0, "9+ yrs": 0}
    for j in jobs:
        exp = j.get("experience", 0)
        if exp <= 1:
            exp_buckets["0-1 yrs"] += 1
        elif exp <= 3:
            exp_buckets["2-3 yrs"] += 1
        elif exp <= 5:
            exp_buckets["4-5 yrs"] += 1
        elif exp <= 8:
            exp_buckets["6-8 yrs"] += 1
        else:
            exp_buckets["9+ yrs"] += 1

    # ── top 20 skills ──
    skill_counter = Counter()
    for j in jobs:
        skill_list = [s.strip() for s in str(j.get("skills", "")).split(",") if s.strip()]
        skill_counter.update(skill_list)
    top_skills = dict(skill_counter.most_common(20))

    return jsonify({
        "total_jobs":              len(jobs),
        "jobs_by_work_type":       dict(work_type_counts),
        "jobs_by_country":         top_countries,
        "jobs_by_role":            top_roles,
        "avg_salary_by_role":      avg_salary_by_role,
        "jobs_posted_by_month":    jobs_by_month,
        "experience_distribution": exp_buckets,
        "top_skills":              top_skills,
    })

# GET /health
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":       "ok",
        "jobs_loaded":  len(jobs),
        "tfidf_features": tfidf_matrix.shape[1],
        "timestamp":    datetime.datetime.utcnow().isoformat() + "Z",
    })

# MAIN
if __name__ == "__main__":

    app.run(host="0.0.0.0", port=5000, debug=False) 