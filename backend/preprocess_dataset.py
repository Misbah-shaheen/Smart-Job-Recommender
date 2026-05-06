#!/usr/bin/env python3
import os, re, json
import pandas as pd

CSV_PATH          = "job_descriptions.csv"
FLUTTER_OUT       = "jobs_flutter.json"   
FLASK_OUT         = "jobs.json"          

FLUTTER_MAX_JOBS  = 25_000   
FLASK_MAX_ROWS    = 50_000   


COLUMN_MAP = {
    "Job Id":            "id",
    "Job Title":         "job_title",
    "skills":            "skills",         
    "Salary Range":      "salary_range",
    "Experience":        "experience",
    "Work Type":         "work_type",
    "Job Description":   "description",
    "Location":          "location",
    "Country":           "country",
    "Latitude":          "latitude",
    "Longitude":         "longitude",
    "Company Name":      "company",         
    "Company":           "company",        
    "Company Size":      "company_size",
    "Role":              "role",
    "Qualifications":    "qualifications",
    "Benefits":          "benefits",
    "Job Posting Date":  "posting_date",
    "Responsibilities":  "responsibilities",
    "Preference":        "preference",
    "Contact Person":    "contact_person",
    "Job Portal":        "job_portal",
    "Company Profile":   "company_profile",
}

# Work type normalisation

def normalise_work_type(raw, job_id=0):
    v = str(raw).strip().lower()
    if v in ("remote",):               return "Remote"
    if v in ("hybrid",):               return "Hybrid"
    if v in ("onsite", "on-site", "on site"): return "Onsite"
    # Kaggle types → distribute pseudo-randomly but consistently
    if "full" in v:
        choices = ["Onsite", "Onsite", "Onsite", "Hybrid", "Remote"]
    elif "part" in v:
        choices = ["Remote", "Remote", "Hybrid", "Hybrid", "Onsite"]
    elif "contract" in v:
        choices = ["Remote", "Remote", "Hybrid", "Onsite", "Onsite"]
    elif "temp" in v:
        choices = ["Hybrid", "Hybrid", "Onsite", "Remote", "Onsite"]
    elif "intern" in v:
        choices = ["Onsite", "Onsite", "Hybrid", "Onsite", "Onsite"]
    else:
        choices = ["Remote", "Hybrid", "Onsite", "Remote", "Hybrid"]
    return choices[int(job_id) % len(choices)]

# Salary parsing 
def parse_salary(raw):
    """Handles '$80,000 - $120,000', '80000-120000', '$80K-$120K', '80000'"""
    s = str(raw).replace(",", "").replace("$", "").upper()
    s = s.replace("K", "000")
    nums = [int(x) for x in re.findall(r"\d+", s) if int(x) > 1000]
    if len(nums) >= 2:
        return (nums[0] + nums[1]) // 2
    if len(nums) == 1:
        return nums[0]
    return 70000  # fallback

# Experience parsing 
def parse_experience(raw):
    """Handles '3 Years', '3-5 Years', '3+', 'Mid Level', 'Senior'"""
    s = str(raw).strip().lower()
    nums = re.findall(r"\d+", s)
    if nums:
        return min(int(nums[0]), 20)
    if any(x in s for x in ["entry", "junior", "fresher", "intern"]):
        return 0
    if any(x in s for x in ["mid", "intermediate"]):
        return 3
    if any(x in s for x in ["senior", "lead", "sr."]):
        return 6
    if any(x in s for x in ["principal", "director", "vp", "head"]):
        return 10
    return 2

# Company size normalisation
def normalise_size(raw):
    s = str(raw).strip()
    # Kaggle format is often "10 to 50 Employees" or "1001 to 5000 Employees"
    nums = [int(x) for x in re.findall(r"\d+", s.replace(",",""))]
    if nums:
        n = max(nums)
        if n <= 50:    return "Small (1-50)"
        if n <= 500:   return "Medium (51-500)"
        if n <= 5000:  return "Large (501-5000)"
        return "Enterprise (5000+)"
    s_lower = s.lower()
    if any(x in s_lower for x in ["small", "startup"]):  return "Small (1-50)"
    if "medium" in s_lower:                              return "Medium (51-500)"
    if "large"  in s_lower:                              return "Large (501-5000)"
    if any(x in s_lower for x in ["enterprise","corp"]): return "Enterprise (5000+)"
    return "Medium (51-500)"

# Main 
def main():
    if not os.path.exists(CSV_PATH):
        print(f"\n'{CSV_PATH}' NOT FOUND in this folder.")
        print("   Download from Kaggle:")
        print("   https://www.kaggle.com/datasets/ravindrasinghrana/job-description-dataset")
        print(f"   Place '{CSV_PATH}' in: {os.path.abspath('.')}")
        print("\n   Using built-in sample (100 jobs) as fallback...")
        use_sample()
        return

    print(f"   Found {CSV_PATH}")
    print(f"   Flutter limit : {FLUTTER_MAX_JOBS:,} jobs")
    print(f"   Flask ML limit: {FLASK_MAX_ROWS:,} rows")

    print(f"\nReading CSV (up to {FLASK_MAX_ROWS:,} rows)...")
    df = pd.read_csv(
        CSV_PATH,
        nrows=FLASK_MAX_ROWS,
        low_memory=False,
        on_bad_lines="skip",
        encoding="utf-8",
    )
    print(f"   Loaded: {len(df):,} rows × {len(df.columns)} columns")
    print(f"   Columns: {list(df.columns)}")

    # Rename columns 
    rename = {k: v for k, v in COLUMN_MAP.items() if k in df.columns}
    df = df.rename(columns=rename)
    print(f"   Renamed {len(rename)} columns")

    # Check if company column is present
    if "company" in df.columns:
        sample_companies = df["company"].dropna().head(5).tolist()
        print(f"  Company column found. Samples: {sample_companies}")
    else:
        print("   'Company Name' column not found! Check your CSV.")
        # Try to find it under another name
        # Only match columns that are specifically about company NAME, not size/profile
        for col in df.columns:
            col_lower = col.lower().strip()
            # Must be about company identity, NOT size, profile, portal etc.
            if col_lower in ("company", "employer", "organization", "company name", "employer name"):
                print(f"   Found alternative: '{col}' — using it")
                df = df.rename(columns={col: "company"})
                break
        else:
            df["company"] = "Unknown Company"

    # Process each field 
    needed = ["job_title", "skills", "company", "location", "work_type",
              "salary_range", "experience", "description", "qualifications",
              "company_size", "country", "latitude", "longitude",
              "role", "posting_date"]

    # Add missing columns with defaults
    defaults = {
        "job_title": "Software Engineer", "skills": "", "company": "Unknown",
        "location": "", "work_type": "Full-Time", "salary_range": "60000-90000",
        "experience": "2", "description": "", "qualifications": "Bachelor's Degree",
        "company_size": "Medium", "country": "", "latitude": "0", "longitude": "0",
        "role": "", "posting_date": "2024-01-01",
    }
    for col, default in defaults.items():
        if col not in df.columns:
            df[col] = default
        else:
            df[col] = df[col].fillna(default)

    # Drop rows with no title or skills
    df = df[df["job_title"].astype(str).str.strip() != ""]
    df = df[df["job_title"].astype(str).str.lower() != "nan"]
    df = df[df["skills"].astype(str).str.strip() != ""]
    df = df[df["skills"].astype(str).str.lower() != "nan"]
    df = df.reset_index(drop=True)
    print(f"   After cleanup: {len(df):,} valid rows")

    # Clean text
    df["job_title"]      = df["job_title"].astype(str).str.strip().str.title()
    df["skills"]         = df["skills"].astype(str).str.strip()
    df["company"]        = df["company"].astype(str).str.strip()
    df["location"]       = df["location"].astype(str).str.strip()
    df["country"]        = df["country"].astype(str).str.strip()
    df["description"]    = df["description"].astype(str).str.strip().str[:400]
    df["qualifications"] = df["qualifications"].astype(str).str.strip()
    df["role"]           = df["role"].astype(str).str.strip()

    # replace nan/null/Unknown Company with empty so we can detect it
    df["company"] = df["company"].replace(["nan", "null", "N/A", "Unknown Company", ""], "Unknown")

    # Parse numeric fields
    df["salary"]     = df["salary_range"].apply(parse_salary)
    df["experience"] = df["experience"].apply(parse_experience)
    df["company_size"] = df["company_size"].apply(normalise_size)
    df["latitude"]   = pd.to_numeric(df["latitude"],  errors="coerce").fillna(0.0).round(4)
    df["longitude"]  = pd.to_numeric(df["longitude"], errors="coerce").fillna(0.0).round(4)

    # Normalise work_type (uses id for deterministic pseudo-random spread)
    df["id"] = range(1, len(df) + 1)
    df["work_type"] = df.apply(
        lambda r: normalise_work_type(r["work_type"], r["id"]), axis=1
    )

    # Date
    df["posting_date"] = pd.to_datetime(
        df["posting_date"], errors="coerce"
    ).dt.strftime("%Y-%m-%d").fillna("2024-01-01")

    print(f"\nProcessed {len(df):,} jobs")

    # Work type distribution
    wt = df["work_type"].value_counts().to_dict()
    sal_avg = int(df["salary"].mean())
    companies_unique = df["company"].nunique()
    print(f"   Work types:        {wt}")
    print(f"   Avg salary:        ${sal_avg:,}")
    print(f"   Unique companies:  {companies_unique:,}")
    print(f"   Sample companies:  {df['company'].head(5).tolist()}")

    # ── Write Flask jobs.json (full dataset for ML) ───────────────────────────
    flask_cols = ["id", "job_title", "skills", "salary", "experience",
                  "work_type", "description", "company", "location", "country",
                  "qualifications", "company_size", "role", "posting_date",
                  "latitude", "longitude"]
    flask_cols = [c for c in flask_cols if c in df.columns]
    flask_records = df[flask_cols].to_dict(orient="records")
    with open(FLASK_OUT, "w", encoding="utf-8") as f:
        json.dump({"jobs": flask_records, "total": len(flask_records)}, f,
                  ensure_ascii=False, separators=(",", ":"))
    size_mb = os.path.getsize(FLASK_OUT) / 1_048_576
    print(f"\n {FLASK_OUT} written: {len(flask_records):,} jobs ({size_mb:.1f} MB)")
    print(f"   Used by Flask ML API (stays in backend/)")
    
    flutter_df = _sample_for_flutter(df, FLUTTER_MAX_JOBS)

    flutter_cols = ["id", "job_title", "skills", "salary", "experience",
                    "work_type", "company", "location", "country",
                    "qualifications", "company_size", "role", "posting_date"]
    # Add short description 
    
    flutter_df = flutter_df.copy()
    flutter_df["description"] = flutter_df["description"].str[:150]
    flutter_cols_available = [c for c in flutter_cols + ["description"]
                               if c in flutter_df.columns]

    flutter_records = flutter_df[flutter_cols_available].to_dict(orient="records")
    with open(FLUTTER_OUT, "w", encoding="utf-8") as f:
        json.dump({"jobs": flutter_records, "total": len(flutter_records)}, f,
                  ensure_ascii=False, indent=2)
    size_mb = os.path.getsize(FLUTTER_OUT) / 1_048_576
    print(f"{FLUTTER_OUT} written: {len(flutter_records):,} jobs ({size_mb:.1f} MB)")

    print(f"\n{'='*55}")
    print(f"  NEXT STEPS:")
    print(f"  1. cp {FLUTTER_OUT} ../assets/data/jobs.json")
    print(f"  2. python app.py")
    print(f"{'='*55}")


def _sample_for_flutter(df: pd.DataFrame, n: int) -> pd.DataFrame:
    """
    Take a diverse stratified sample:
    - Proportional across work_type (Remote/Hybrid/Onsite)
    - Spread across experience levels
    - Real companies prioritised (not 'Unknown')
    """
    # Prefer rows with known company
    known = df[df["company"] != "Unknown"]
    unknown = df[df["company"] == "Unknown"]
    # Take as many known-company rows as possible
    if len(known) >= n:
        pool = known
    else:
        pool = pd.concat([known, unknown.head(n - len(known))])

    if len(pool) <= n:
        return pool.reset_index(drop=True)

    # Stratified sample by work_type
    sampled = pool.groupby("work_type", group_keys=False).apply(
        lambda g: g.sample(min(len(g), int(n * len(g) / len(pool)) + 1), random_state=42)
    )
    return sampled.head(n).reset_index(drop=True)


def use_sample():
    """Generates a clean 100-job sample with REAL-looking company names."""
    companies = [
        "Google LLC", "Microsoft Corporation", "Amazon Web Services",
        "Apple Inc.", "Meta Platforms", "Netflix Inc.", "Salesforce",
        "IBM Corporation", "Oracle Corporation", "Adobe Systems",
        "Airbnb Inc.", "Uber Technologies", "Lyft Inc.", "Stripe Inc.",
        "Spotify Technology", "Twitter Inc.", "LinkedIn Corporation",
        "Dropbox Inc.", "Slack Technologies", "Zoom Video Communications",
        "PayPal Holdings", "Square Inc.", "Shopify Inc.", "GitHub Inc.",
        "Atlassian Corporation", "PNC Financial Services Group",
        "JPMorgan Chase", "Goldman Sachs", "Icahn Enterprises",
        "Deloitte Consulting", "Accenture PLC", "McKinsey & Company",
        "Boston Consulting Group", "Bain & Company", "EY Advisory",
        "KPMG International", "PwC Advisory", "Capgemini SE",
        "Infosys Limited", "Tata Consultancy Services", "Wipro Limited",
        "HCL Technologies", "Cognizant Technology", "Fiserv Inc.",
        "Automatic Data Processing", "Workday Inc.", "ServiceNow Inc.",
        "VMware Inc.", "Palo Alto Networks", "CrowdStrike Holdings",
    ]
    jobs_data = [
        ("Flutter Developer",          "Flutter,Dart,Firebase,Provider,BLoC,REST API",           "Remote",  90000,  2, "New York, US",       "Bachelor's Degree", "Medium (51-500)"),
        ("Senior Flutter Developer",   "Flutter,Dart,Firebase,GetX,Riverpod,CI/CD",              "Remote", 115000,  5, "San Francisco, US",   "Bachelor's Degree", "Large (501-5000)"),
        ("Python Backend Engineer",    "Python,Flask,PostgreSQL,Redis,Docker,REST API",           "Onsite",  95000,  3, "Seattle, US",         "Bachelor's Degree", "Large (501-5000)"),
        ("Senior Python Engineer",     "Python,FastAPI,Celery,PostgreSQL,Kubernetes",             "Remote", 125000,  6, "Austin, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Machine Learning Engineer",  "Python,TensorFlow,Scikit-learn,Pandas,MLOps",            "Remote", 130000,  4, "Boston, US",          "Master's Degree",   "Large (501-5000)"),
        ("Senior ML Engineer",         "PyTorch,TensorFlow,MLflow,Kubeflow,Python",              "Remote", 150000,  7, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Data Scientist",             "Python,Pandas,NumPy,Scikit-learn,SQL,Tableau",           "Hybrid", 118000,  4, "Chicago, US",         "Master's Degree",   "Large (501-5000)"),
        ("Senior Data Scientist",      "Python,R,Statistics,ML,SQL,Spark",                       "Remote", 140000,  7, "Los Angeles, US",     "Master's Degree",   "Enterprise (5000+)"),
        ("React Developer",            "React,TypeScript,Redux,Next.js,CSS,GraphQL",             "Hybrid",  92000,  2, "Denver, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Senior React Developer",     "React,TypeScript,Next.js,GraphQL,Testing Library",       "Hybrid", 118000,  5, "Austin, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Node.js Developer",          "Node.js,Express,TypeScript,MongoDB,PostgreSQL",          "Remote",  90000,  3, "Miami, US",           "Bachelor's Degree", "Medium (51-500)"),
        ("Full Stack Developer",       "React,Node.js,MongoDB,Express,TypeScript,Docker",        "Hybrid", 102000,  4, "Portland, US",        "Bachelor's Degree", "Medium (51-500)"),
        ("DevOps Engineer",            "Docker,Kubernetes,AWS,Terraform,CI/CD,Linux",            "Onsite", 108000,  4, "Atlanta, US",         "Bachelor's Degree", "Large (501-5000)"),
        ("Senior DevOps Engineer",     "Kubernetes,AWS,Terraform,Ansible,Python,Prometheus",     "Remote", 132000,  7, "Remote, US",          "Bachelor's Degree", "Enterprise (5000+)"),
        ("Android Developer",          "Kotlin,Android,Jetpack Compose,Firebase,Room",           "Remote",  92000,  3, "Boston, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Senior Android Developer",   "Kotlin,MVVM,Coroutines,Jetpack,Firebase,CI/CD",          "Onsite", 118000,  6, "Seattle, US",         "Bachelor's Degree", "Enterprise (5000+)"),
        ("iOS Developer",              "Swift,SwiftUI,UIKit,Firebase,Core Data",                 "Onsite", 105000,  3, "Chicago, US",         "Bachelor's Degree", "Large (501-5000)"),
        ("Senior iOS Developer",       "Swift,SwiftUI,Combine,ARKit,Core ML",                   "Remote", 125000,  6, "San Francisco, US",   "Bachelor's Degree", "Enterprise (5000+)"),
        ("AWS Solutions Architect",    "AWS,CloudFormation,Terraform,Python,Lambda",             "Remote", 132000,  6, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Cloud Engineer",             "AWS,Azure,GCP,Kubernetes,Terraform,Docker",              "Hybrid", 115000,  5, "Dallas, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Data Engineer",              "Python,Apache Spark,Kafka,Airflow,SQL,dbt",              "Remote", 118000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Java Developer",             "Java,Spring Boot,Hibernate,Maven,PostgreSQL",            "Onsite",  98000,  3, "Columbus, US",        "Bachelor's Degree", "Large (501-5000)"),
        ("Senior Java Engineer",       "Java,Spring Boot,Microservices,Kafka,Docker",            "Hybrid", 122000,  6, "Chicago, US",         "Bachelor's Degree", "Enterprise (5000+)"),
        ("TypeScript Developer",       "TypeScript,React,Node.js,GraphQL,Jest",                  "Hybrid",  95000,  3, "San Francisco, US",   "Bachelor's Degree", "Medium (51-500)"),
        ("UI/UX Designer",             "Figma,Adobe XD,User Research,Prototyping,CSS",           "Remote",  78000,  2, "Miami, US",           "Bachelor's Degree", "Small (1-50)"),
        ("Product Designer",           "Figma,Design Systems,User Research,Sketch",              "Hybrid",  92000,  3, "New York, US",        "Bachelor's Degree", "Medium (51-500)"),
        ("Cybersecurity Engineer",     "Python,Linux,Networking,SIEM,Penetration Testing",       "Onsite", 112000,  4, "Washington DC, US",   "Bachelor's Degree", "Large (501-5000)"),
        ("React Native Developer",     "React Native,TypeScript,Firebase,Redux,Expo",            "Remote",  88000,  2, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Go Developer",               "Go,Microservices,Docker,PostgreSQL,gRPC",               "Remote", 108000,  4, "Remote, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Blockchain Developer",       "Solidity,Ethereum,Web3.js,Smart Contracts,Python",      "Remote", 120000,  4, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("NLP Engineer",               "Python,NLP,BERT,Transformers,PyTorch,spaCy",            "Remote", 128000,  5, "Remote, US",          "Master's Degree",   "Large (501-5000)"),
        ("Computer Vision Engineer",   "Python,OpenCV,TensorFlow,PyTorch,CUDA",                 "Remote", 130000,  5, "Remote, US",          "Master's Degree",   "Large (501-5000)"),
        ("Site Reliability Engineer",  "Kubernetes,Python,Linux,Prometheus,Grafana",            "Hybrid", 118000,  5, "San Jose, US",        "Bachelor's Degree", "Enterprise (5000+)"),
        ("Platform Engineer",          "Kubernetes,Terraform,Go,AWS,CI/CD,Istio",               "Remote", 122000,  6, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("QA Automation Engineer",     "Selenium,Python,Jest,Cypress,CI/CD,Playwright",         "Hybrid",  82000,  3, "Columbus, US",        "Bachelor's Degree", "Large (501-5000)"),
        ("ETL Developer",              "Python,Apache Spark,SQL,Airflow,Kafka,dbt",             "Remote",  98000,  4, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Kubernetes Engineer",        "Kubernetes,Docker,Helm,Prometheus,Python,Go",           "Remote", 120000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Power BI Developer",         "Power BI,DAX,SQL,Azure,Excel,Data Modeling",            "Onsite",  80000,  2, "Dallas, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Tableau Developer",          "Tableau,SQL,Python,Data Visualization,Analytics",       "Hybrid",  82000,  2, "New York, US",        "Bachelor's Degree", "Medium (51-500)"),
        ("Product Manager",            "Agile,Jira,SQL,Product Strategy,Roadmapping,User Research","Hybrid",115000, 5, "San Francisco, US",  "MBA",               "Large (501-5000)"),
        ("Scrum Master",               "Agile,Scrum,Kanban,Jira,Confluence,Facilitation",       "Hybrid",  95000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Database Administrator",     "PostgreSQL,MySQL,Redis,SQL,Performance Tuning",          "Onsite",  92000,  4, "Chicago, US",         "Bachelor's Degree", "Large (501-5000)"),
        ("Embedded Systems Engineer",  "C,C++,RTOS,ARM,Linux,Firmware",                         "Onsite",  96000,  4, "Detroit, US",         "Bachelor's Degree", "Large (501-5000)"),
        ("Unity Developer",            "Unity,C#,Game Physics,3D Modeling,Blender",             "Onsite",  90000,  3, "Los Angeles, US",     "Bachelor's Degree", "Medium (51-500)"),
        ("Rust Developer",             "Rust,WebAssembly,Systems Programming,Linux,C++",        "Remote", 120000,  5, "Remote, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Vue.js Developer",           "Vue.js,JavaScript,Vuex,TypeScript,CSS,Node.js",         "Hybrid",  88000,  2, "Seattle, US",         "Bachelor's Degree", "Medium (51-500)"),
        ("Spark Developer",            "Apache Spark,Python,Scala,SQL,Hadoop,Hive",             "Remote", 118000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("ML Research Scientist",      "PyTorch,Research,Python,CUDA,Mathematics,Papers",       "Remote", 150000,  8, "Remote, US",          "PhD",               "Enterprise (5000+)"),
        ("Principal Engineer",         "System Design,Python,Go,Leadership,Architecture",       "Remote", 165000, 12, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Staff Engineer",             "Architecture,Python,Distributed Systems,Go,SQL",        "Remote", 158000, 10, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Deep Learning Engineer",     "PyTorch,CUDA,Python,Computer Vision,NLP,GPUs",          "Remote", 140000,  6, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Salesforce Developer",       "Salesforce,Apex,LWC,SOQL,CRM,Visualforce",             "Onsite",  96000,  3, "Dallas, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Snowflake Engineer",         "Snowflake,SQL,dbt,Python,Data Warehousing,ELT",         "Remote", 108000,  4, "Remote, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("GraphQL Developer",          "GraphQL,Node.js,Apollo,TypeScript,PostgreSQL",           "Remote",  98000,  3, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Firmware Developer",         "C,C++,ARM,RTOS,Hardware,Embedded Linux",                "Onsite",  94000,  4, "Austin, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("XR Developer",               "Unity,C#,ARCore,Oculus SDK,3D Modeling,VR",             "Hybrid", 110000,  4, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Technical Writer",           "Documentation,Markdown,API Docs,Git,Confluence",        "Remote",  72000,  2, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Business Intelligence Analyst","SQL,Power BI,Excel,Tableau,Python,Statistics",        "Hybrid",  75000,  2, "Atlanta, US",         "Bachelor's Degree", "Medium (51-500)"),
        ("Data Analyst",               "SQL,Tableau,Python,Excel,Power BI,Data Cleaning",       "Hybrid",  74000,  2, "Phoenix, US",         "Bachelor's Degree", "Medium (51-500)"),
        ("Infrastructure Engineer",    "AWS,Terraform,Ansible,Linux,Docker,Networking",         "Onsite", 108000,  5, "New York, US",        "Bachelor's Degree", "Enterprise (5000+)"),
        ("IoT Engineer",               "Embedded C,Python,MQTT,Linux,Arduino,Raspberry Pi",    "Onsite",  92000,  3, "Detroit, US",         "Bachelor's Degree", "Medium (51-500)"),
        ("Mobile Security Engineer",   "iOS,Android,Security,Reverse Engineering,OWASP",        "Remote", 120000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Kafka Engineer",             "Apache Kafka,Java,Python,Streaming,Docker,Zookeeper",   "Remote", 115000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Lead Mobile Engineer",       "Flutter,React Native,iOS,Android,Architecture,CI/CD",   "Remote", 135000,  8, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("Lead Data Scientist",        "Python,ML,Statistics,Leadership,SQL,Communication",     "Remote", 145000,  8, "Remote, US",          "Master's Degree",   "Enterprise (5000+)"),
        ("SRE Lead",                   "Kubernetes,SLOs,Python,Prometheus,On-call,Linux",       "Remote", 138000,  7, "Remote, US",          "Bachelor's Degree", "Enterprise (5000+)"),
        ("Cloud Security Engineer",    "AWS,IAM,Python,Security,Terraform,Compliance",          "Remote", 125000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("ML Platform Engineer",       "MLOps,Python,Kubernetes,Kubeflow,Docker,Airflow",       "Remote", 130000,  6, "Remote, US",          "Master's Degree",   "Large (501-5000)"),
        ("Robotics Software Engineer", "ROS,Python,C++,Computer Vision,Linux,SLAM",             "Onsite", 118000,  5, "Boston, US",          "Master's Degree",   "Medium (51-500)"),
        ("Kotlin Developer",           "Kotlin,Android,Coroutines,Jetpack Compose,Firebase",    "Onsite",  94000,  3, "Houston, US",         "Bachelor's Degree", "Medium (51-500)"),
        ("Swift Developer",            "Swift,SwiftUI,UIKit,Xcode,Combine,Core Data",           "Onsite", 102000,  3, "Cupertino, US",       "Bachelor's Degree", "Medium (51-500)"),
        ("Systems Programmer",         "C,C++,Linux,Assembly,Operating Systems,Drivers",        "Onsite", 112000,  5, "San Jose, US",        "Master's Degree",   "Large (501-5000)"),
        ("Technical PM",               "SQL,Agile,API Design,Jira,Roadmapping,Communication",   "Hybrid", 122000,  6, "San Francisco, US",   "MBA",               "Enterprise (5000+)"),
        ("Agile Coach",                "Agile,Scrum,Kanban,Coaching,Facilitation,Leadership",   "Hybrid", 102000,  6, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Django Developer",           "Python,Django,PostgreSQL,REST API,Celery,Redis",        "Onsite",  92000,  3, "Boston, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Firebase Developer",         "Firebase,Flutter,Dart,Cloud Functions,Firestore",       "Remote",  84000,  2, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Penetration Tester",         "Kali Linux,Python,Metasploit,Networking,OWASP,Burp",    "Remote", 112000,  4, "Remote, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Linux Systems Admin",        "Linux,Bash,Networking,Docker,Ansible,Cron",             "Onsite",  88000,  4, "Charlotte, US",       "Bachelor's Degree", "Large (501-5000)"),
        ("Senior Full Stack Engineer", "React,Node.js,PostgreSQL,Docker,TypeScript,Redis",      "Hybrid", 122000,  6, "Austin, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Senior Backend Engineer",    "Go,PostgreSQL,Redis,gRPC,Docker,Microservices",         "Remote", 128000,  6, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Senior Frontend Engineer",   "React,TypeScript,Next.js,CSS,Testing,Webpack",          "Hybrid", 118000,  6, "Seattle, US",         "Bachelor's Degree", "Large (501-5000)"),
        ("Graph Database Engineer",    "Neo4j,GraphQL,Python,Cypher,Graph Theory",              "Remote", 110000,  5, "Remote, US",          "Bachelor's Degree", "Medium (51-500)"),
        ("Apache Spark Engineer",      "Apache Spark,Python,Scala,SQL,Delta Lake,Databricks",   "Remote", 118000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Unreal Engine Developer",    "C++,Unreal Engine,Blueprints,3D Modeling,Game Design",  "Onsite", 102000,  4, "Los Angeles, US",     "Bachelor's Degree", "Medium (51-500)"),
        ("Senior QA Engineer",         "Selenium,Python,API Testing,CI/CD,Playwright,Jest",     "Hybrid",  92000,  5, "Austin, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Data Platform Engineer",     "Snowflake,dbt,Python,Airflow,SQL,Data Modeling",        "Remote", 118000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Kotlin Multiplatform Dev",   "Kotlin,KMM,Android,iOS,Coroutines,Compose MP",          "Remote", 100000,  4, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("AR/VR Developer",            "Unity,C#,ARCore,ARKit,Oculus,3D Modeling,Shaders",     "Remote", 105000,  4, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Senior DevOps Lead",         "Kubernetes,AWS,Terraform,Python,Ansible,GitOps",        "Remote", 142000,  8, "Remote, US",          "Bachelor's Degree", "Enterprise (5000+)"),
        ("Cloud Native Developer",     "Go,Kubernetes,Docker,Istio,gRPC,Service Mesh",          "Remote", 120000,  5, "Remote, US",          "Bachelor's Degree", "Large (501-5000)"),
        ("Web3 Developer",             "Solidity,Ethereum,Hardhat,TypeScript,React,IPFS",       "Remote", 118000,  4, "Remote, US",          "Bachelor's Degree", "Small (1-50)"),
        ("Microservices Architect",    "Java,Spring Boot,Docker,Kubernetes,Kafka,Domain Design", "Hybrid", 142000,  8, "San Francisco, US",  "Master's Degree",   "Enterprise (5000+)"),
        ("MLOps Engineer",             "MLOps,Python,Kubernetes,Docker,Kubeflow,Feast",         "Remote", 132000,  6, "Remote, US",          "Master's Degree",   "Large (501-5000)"),
        ("Analytics Engineer",         "dbt,SQL,Python,Snowflake,Looker,Data Modeling",         "Remote", 102000,  3, "Remote, US",          "Bachelor's Degree", "Medium (51-500)"),
    ]

    jobs = []
    import random; random.seed(42)
    for i, row in enumerate(jobs_data, 1):
        title, skills, wt, salary, exp, location, qual, size = row
        company = companies[i % len(companies)]
        jobs.append({
            "id": i, "job_title": title, "skills": skills,
            "salary": salary, "experience": exp, "work_type": wt,
            "description": f"Join {company} as a {title}. Work on impactful projects with a talented engineering team.",
            "company": company, "location": location,
            "qualifications": qual, "company_size": size,
            "role": title.split()[0], "posting_date": "2024-01-01",
        })

    output = {"jobs": jobs, "total": len(jobs)}

    # Write both files
    with open(FLASK_OUT,   "w") as f: json.dump(output, f, ensure_ascii=False, separators=(",",":"))
    with open(FLUTTER_OUT, "w") as f: json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Generated {len(jobs)} sample jobs (real company names)")
    print(f"   Sample companies: {[j['company'] for j in jobs[:5]]}")
    print(f"\n{'='*55}")
    print(f"  NEXT STEPS:")
    print(f"  1. cp {FLUTTER_OUT} ../assets/data/jobs.json")
    print(f"  2. python app.py")
    print(f"{'='*55}")


if __name__ == "__main__":
    main()