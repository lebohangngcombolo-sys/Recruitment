# 🚀 Deployment Environment Variables Setup

## 🤖 Hugging Face Spaces Variables (CV Analyser)

### 🔑 Critical Required Variables:
```bash
# Core Configuration
ENVIRONMENT=production
DATABASE_URL=postgresql://recruiter:zhubXkTYjieGoYevXB7jtHj5EdhNYmV7@dpg-d6v72fchg0os73ddre00-a.oregon-postgres.render.com/analyser_w2n9?sslmode=require
SIGNING_SECRET=your-secure-32-char-secret-here
HF_API_TOKEN=hf_your_hugging_face_token

# Production Hardening
APP_VERSION=1.0.0
CV_ANALYSER_UPLOAD_TIMEOUT=60
CV_ANALYSER_STATUS_TIMEOUT=60
CV_ANALYSER_RESULT_TIMEOUT=60
CV_ANALYSER_MAX_RETRIES=3
CV_TEXT_MIN_LENGTH=50
ENABLE_JWT_FALLBACK=true
JWT_FALLBACK_TTL=120

# CORS - IMPORTANT FOR RECRUITMENT APP
ALLOW_ORIGINS=https://your-recruitment-app.com,http://localhost:5001,http://localhost:3000
```

### 📋 How to Set on Hugging Face:
1. Go to your Hugging Face Space: https://huggingface.co/spaces/Dzunisani007/cv-analyser
2. Click on "Settings" tab
3. Scroll to "Variables and secrets"
4. Add each variable as a "New secret"

## 📱 Recruitment App Variables

### 🔑 Critical Required Variables:
```bash
# CV Analyser Connection
CV_ANALYSER_BASE_URL=https://dzunisani007-cv-analyser.hf.space
CV_ANALYSER_SIGNING_SECRET=your-secure-32-char-secret-here

# Database (same as HF Spaces)
DATABASE_URL=postgresql://recruiter:zhubXkTYjieGoYevXB7jtHj5EdhNYmV7@dpg-d6v72fchg0os73ddre00-a.oregon-postgres.render.com/analyser_w2n9?sslmode=require

# Production Hardening
APP_VERSION=1.0.0
CV_ANALYSER_UPLOAD_TIMEOUT=60
CV_ANALYSER_STATUS_TIMEOUT=60
CV_ANALYSER_RESULT_TIMEOUT=60
CV_ANALYSER_MAX_RETRIES=3
CV_TEXT_MIN_LENGTH=50
ENABLE_JWT_FALLBACK=true
JWT_FALLBACK_TTL=120

# CORS - IMPORTANT FOR CV ANALYSER
ALLOW_ORIGINS=https://dzunisani007-cv-analyser.hf.space,http://localhost:5001,http://localhost:3000
```

### 📋 How to Set on Recruitment App:
Add these to your `.env` file in the recruitment app directory.

## 🔧 Variable Explanations

### 🔐 Security Variables:
- **SIGNING_SECRET**: 32-character secret for JWT tokens
- **HF_API_TOKEN**: Your Hugging Face API token (if using HF models)

### ⏱️ Timeout Variables:
- **CV_ANALYSER_UPLOAD_TIMEOUT**: 60 seconds for CV upload
- **CV_ANALYSER_STATUS_TIMEOUT**: 60 seconds for status checks
- **CV_ANALYSER_RESULT_TIMEOUT**: 60 seconds for result retrieval

### 🔄 Retry Variables:
- **CV_ANALYSER_MAX_RETRIES**: 3 retry attempts on failure
- **ENABLE_JWT_FALLBACK**: Enable JWT token regeneration
- **JWT_FALLBACK_TTL**: 120 seconds for fallback tokens

### 🌐 CORS Variables:
- **ALLOW_ORIGINS**: Comma-separated list of allowed domains
- Must include both services for proper communication

## 🧪 Test the Deployment

### 1. Test CV Analyser Health:
```bash
curl -X GET "https://dzunisani007-cv-analyser.hf.space/health"
```

### 2. Test CV Analysis:
```bash
curl -X POST "https://dzunisani007-cv-analyser.hf.space/api/v1/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "cv_text": "JOHN DOE\nSoftware Engineer\nExperience: 5 years in Python development\nSkills: Python, Django, PostgreSQL\n\nPROFESSIONAL EXPERIENCE\nSenior Software Engineer | TechCorp | 2020-Present\n- Developed web applications using Python and Django\n- Worked with PostgreSQL databases\n- Led team of 3 developers\n\nEDUCATION\nBSc Computer Science | University | 2016-2020\n\nSKILLS\nPython, Django, PostgreSQL, JavaScript, Git",
    "job_description": "Senior Software Developer with 5+ years experience in Python and Django"
  }'
```

### 3. Test Recruitment App Integration:
```bash
# From recruitment app directory
python test_bob_cv_accuracy.py
```

## 🚨 Important Notes

### 🔑 Matching Secrets:
- **CV_ANALYSER_SIGNING_SECRET** must be identical in both services
- This enables JWT token validation between services

### 🌐 CORS Configuration:
- Both services must allow each other's domains
- Include localhost for development/testing

### 📊 Monitoring:
- Health endpoint provides system metrics
- Monitor error rates and response times
- Set up alerts for high error rates

## ✅ Deployment Verification Checklist

- [ ] Hugging Face variables set
- [ ] Recruitment app variables set
- [ ] CV Analyser health check passes
- [ ] CV analysis endpoint works
- [ ] Recruitment app can connect to CV Analyser
- [ ] End-to-end test with Bob's CV works
- [ ] Error rates are acceptable (<5%)
- [ ] Monitoring metrics are collecting

## 🎯 Next Steps

1. **Set environment variables** on both services
2. **Test the connection** between services
3. **Run the Bob CV test** to verify accuracy
4. **Monitor the system** for any issues
5. **Deploy to production** when ready

Your CV Analyser is now deployed and ready for integration! 🚀
