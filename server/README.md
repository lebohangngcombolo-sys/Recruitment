For fluuter fronend : cd khono_recruite
                    : pub get
                    : flutter run -d chrome --web-port=3000


for Python backend: cd server
                  : python -m venv .venv
                  : .\.venv\Scripts\Activate.ps1   (Windows PowerShell) or  source .venv/bin/activate  (WSL/Linux)
                  : pip install -r requirements.txt
                  : python run.py

Render deployment (recommended):
1) Use the repo root `render.yaml` (Render Blueprint) to create:
   - recruitment-api (web)
   - recruitment-worker (celery)
   - recruitment-web (static)
2) Fill env vars in Render using `render.env.template` as a local guide.
3) Health check endpoint: GET /api/public/healthz
4) Production Gunicorn settings are read from:
   GUNICORN_WORKERS, GUNICORN_TIMEOUT, GUNICORN_GRACEFUL_TIMEOUT, GUNICORN_KEEPALIVE
   (defaults are set in server/render_start.sh)

Run migration press Ctrl + C to stop the terminal  

              Run : flask db init
                  : flask db migrate
                  : flask db upgrade
                  : python run.py


Backend .env :

SECRET_KEY=
JWT_SECRET_KEY=
DATABASE_URL=postgresql://<username>:<password>@localhost:5432/<db_name>
MONGO_URI=
REDIS_URL=
MAIL_SERVER=
MAIL_PORT=
MAIL_USE_TLS=
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_DEFAULT_SENDER=
MAIL_TIMEOUT=60
# Optional: use SendGrid HTTP API instead of SMTP (avoids ETIMEDOUT on Render)
SENDGRID_API_KEY=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
FLASK_DEBUG=True
GEMINI_API_KEY=
OPENROUTER_API_KEY=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
DEEPSEEK_API_KEY
FRONTEND_URL=http://localhost:3000

# Supabase Configuration
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Auth0 / SSO Configuration
SSO_CLIENT_ID=
SSO_CLIENT_SECRET=
SSO_METADATA_URL=
SSO_USERINFO_URL=


# POWER BI CONNECTION

http://127.0.0.1:5000/api/admin/powerbi/data

Authorization Bearer $token

Open another terminal : for Python backend: cd server
                  : .\.venv\Scripts\Activate.ps1   (or  source .venv/bin/activate  on WSL)
                  : python test.py

copy the Token and repace "$token" with your actual token



# SSO Connection:
                  


# FRONTEND STRUCTURE

├── android/
├── ios/
├── web/
├── assets/
│   ├── images/
│   │   ├── login_bg.jpg
│   │   ├── register_bg.jpg
│   │   └── landing_bg.jpg
│   └── animations/
│       ├── landing_animation.json
│       ├── applications.json
│       ├── interview.json
│       ├── profile.json
│       ├── jobs.json
│       └── reports.json
├── lib/
│   ├── main.dart
│   ├── constants/
│   │   ├── api_endpoints.dart
│   │   └── app_colors.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── job_model.dart
│   │   ├── application_model.dart
│   │   └── assessment_model.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   └── admin_service.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── reset_password_screen.dart
│   │   ├── admin/
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── job_list_screen.dart
│   │   │   ├── applications_screen.dart
│   │   │   ├── candidates_screen.dart
│   │   │   └── assessment_screen.dart
│   │   ├── candidate/
│   │   │   └── candidate_dashboard.dart
│   │   └── hiring_manager/
│   │       └── hm_dashboard_mock.dart
│   ├── widgets/
│   │   ├── glass_card.dart
│   │   ├── custom_button.dart
│   │   ├── animated_glass_button.dart
│   │   └── nav_drawer.dart
│   ├── utils/
│   │   └── theme_utils.dart
│   └── routes/
│       └── app_routes.dart
├── pubspec.yaml
└── README.md


----------------------------------------------------------------------------------------------
 [Candidate] --------------------------
 |  POST /api/auth/register
 |  POST /api/auth/verify
 |  POST /api/auth/login
 |  POST /api/auth/refresh
 |  POST /api/auth/forgot-password
 |  POST /api/auth/reset-password
 |  GET  /api/auth/me
 |  GET  /api/dashboard/candidate
 |  POST /api/candidates/upload-cv
 |  PUT  /api/candidates/profile
 |  GET  /api/jobs
 |  POST /api/jobs/<job_id>/apply
 |  POST /api/applications/<application_id>/assessment
 |
 v
[CV Upload] --CVParser--> Parsed Profile Data
 |
 v
[Applications] --> stored in DB
 |
 v
[Assessments] --MatchingService--> Scores + Recommendation


[Hiring Manager] ---------------------
 |  POST /api/auth/login
 |  POST /api/auth/refresh
 |  GET  /api/auth/me
 |  GET  /api/dashboard/hiring-manager
 |  POST /api/jobs
 |  GET  /api/jobs/<job_id>/candidates
 |  POST /api/jobs/<job_id>/shortlist
 |  GET  /api/applications/<application_id>/assessment
 |
 v
[Jobs Created] --> Candidates Apply
 |
 v
[Shortlist] --MatchingService--> Proceed / Reject
 |
 v
[Interview Emails] sent via EmailService


[Admin] -------------------------------
 |  POST /api/auth/login
 |  POST /api/auth/refresh
 |  GET  /api/auth/me
 |  GET  /api/dashboard/admin
 |  GET  /api/admin/users
 |  GET  /api/admin/jobs
 |  GET  /api/admin/applications
 |  PUT  /api/admin/role/<user_id>
 |  POST /api/jobs
 |  GET  /api/jobs/<job_id>/candidates
 |  POST /api/jobs/<job_id>/shortlist
 |  GET  /api/applications/<application_id>/assessment
 |
 v
[Full Control] over Users, Jobs, Applications, Shortlisting, Assessments


Candidate
   |
   v
[Register] --> [Verify Email] --> [Login] --> [Onboarding] --> [Dashboard]
   |
   v
[Upload CV] --CVParser--> Candidate.profile
   |
   v
[View Jobs] --> [Apply for Job] --> Application Table
   |
   v
[Submit Assessment] --> MatchingService --> Score & Recommendation
   |
   v
-----------------------------
          |
          v
Hiring Manager/Admin
   |
   v
[Create Jobs] --> [View Candidates for Job] --> [Shortlist Candidates]
   |
   v
[Send Interview Emails]