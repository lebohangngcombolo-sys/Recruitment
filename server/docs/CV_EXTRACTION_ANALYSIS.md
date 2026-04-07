# CV Extraction Analysis - Root Cause Identification

## 🔍 **PROBLEM IDENTIFIED**

The CV extraction is failing due to **multiple critical issues** in the AI model's parsing logic:

---

## 📊 **CURRENT EXTRACTION RESULTS**

### ✅ **What's Working (100% accuracy):**
- **Personal Information**: Name, email, phone, LinkedIn, GitHub ✅
- **Basic Education**: Degree names detected ✅

### ❌ **What's Failing (0% accuracy):**
- **Skills Extraction**: Only 2 skills detected (should be 18+) ❌
- **Experience Parsing**: Title/company are null ❌  
- **Certifications**: Only 1 detected (should be 4) ❌

---

## 🚨 **ROOT CAUSES ANALYSIS**

### **1. Skills Extraction Failure**
**Expected**: 18+ skills (Python, Pandas, NumPy, SQL, AWS Glue, etc.)
**Actual**: Only 2 skills (`aws`, `python`)

**Issues:**
- AI model only extracts skills mentioned in job description
- Misses skills in "CORE SKILLS" section
- Doesn't parse categorized skills (Programming, Data Engineering, etc.)
- Ignores technical skills in experience descriptions

### **2. Experience Parsing Failure**
**Expected**: "Data Analyst at Amazon Web Services (AWS)"
**Actual**: `title: null, company: null`

**Issues:**
- Timeline parsing broken - only extracts dates
- Company name recognition failing
- Job title extraction not working
- Experience description truncated

### **3. Education Structure Issues**
**Expected**: Degree + University separate
**Actual**: Two entries with mixed data

**Issues:**
- University treated as degree
- Institution field always null
- Dates not properly associated

### **4. Certification Extraction Problems**
**Expected**: 4 specific certifications
**Actual**: Only "AWS Certified" (partial)

**Issues:**
- Truncates certification names
- Doesn't parse bullet points properly
- Missing full certification titles

---

## 🔧 **TECHNICAL ISSUES**

### **API Response Structure Problems:**
```json
{
  "structured_data": {
    "skills": ["aws", "python"],  // Should be 18+ skills
    "work_experience": [
      {
        "title": null,           // Should be "Data Analyst"
        "company": null,         // Should be "Amazon Web Services"
        "description": "Jan 2021 – Present"  // Truncated
      }
    ],
    "education": [
      {
        "degree": "Bachelor of Science in Data Science",
        "institution": null      // Should be "University of Cape Town"
      },
      {
        "degree": "University of Cape Town",  // Wrong field
        "institution": null
      }
    ]
  }
}
```

### **Parsing Logic Failures:**
1. **Section Recognition**: Fails to identify "CORE SKILLS", "PROFESSIONAL EXPERIENCE", "CERTIFICATIONS"
2. **Bullet Point Parsing**: Misses skills in bullet format
3. **Company Name Extraction**: Doesn't recognize "Amazon Web Services (AWS)"
4. **Skill Categorization**: Ignores skill categories
5. **Date Association**: Doesn't link dates to experiences/education

---

## 🎯 **SPECIFIC EXTRACTION FAILURES**

### **Skills Section Analysis:**
```
CORE SKILLS
Programming: Python (Pandas, NumPy, Scikit-learn), R
Data Engineering: SQL, ETL, AWS Glue, Lambda
Cloud & Analytics: AWS Redshift, S3, Athena, QuickSight
Visualization: Power BI, Tableau, QuickSight
Machine Learning: Regression, classification, forecasting
Other: Git, API integrations, Agile/Scrum
```

**Extracted**: Only `aws`, `python`
**Missing**: 16+ skills including Pandas, NumPy, SQL, ETL, etc.

### **Experience Section Analysis:**
```
PROFESSIONAL EXPERIENCE
Amazon Web Services (AWS), Cape Town — Data Analyst
Jan 2021 – Present
- [6 bullet points with achievements]
```

**Extracted**: `title: null, company: null`
**Missing**: Company, title, all achievements

### **Certifications Section Analysis:**
```
Certifications
- AWS Certified Data Analytics – Specialty
- AWS Certified Solutions Architect – Associate
- Google Data Analytics Certificate
- Tableau Desktop Specialist
```

**Extracted**: Only "AWS Certified"
**Missing**: 3.5 full certification names

---

## 🚨 **CRITICAL INFERENCE**

The AI model is **fundamentally broken** for CV parsing:

1. **Section Recognition**: Cannot identify standard CV sections
2. **Structured Data Extraction**: Fails to parse organized content
3. **Entity Recognition**: Poor at extracting companies, titles, skills
4. **Bullet Point Processing**: Ignores formatted lists
5. **Context Understanding**: Doesn't understand CV structure

---

## 💡 **RECOMMENDED SOLUTIONS**

### **Immediate Fixes Needed:**

1. **Improve Section Detection**
   - Add regex patterns for "CORE SKILLS", "EXPERIENCE", "EDUCATION"
   - Better header recognition

2. **Fix Skills Extraction**
   - Parse categorized skill sections
   - Extract skills from bullet points
   - Include technical skills from experience

3. **Repair Experience Parsing**
   - Company name extraction logic
   - Job title recognition
   - Date association

4. **Enhance Certification Detection**
   - Parse bullet points
   - Full certification name extraction

### **Long-term Solutions:**

1. **Model Retraining**: Better CV parsing dataset
2. **Rule-based Extraction**: Fallback parsing rules
3. **Template Matching**: CV format recognition
4. **NLP Enhancement**: Better entity recognition

---

## 🎯 **PRIORITY ASSESSMENT**

**CRITICAL (Fix Immediately):**
- Skills extraction (0% accuracy)
- Experience parsing (0% accuracy)

**HIGH PRIORITY:**
- Certification extraction (25% accuracy)
- Education structure fixes

**MEDIUM PRIORITY:**
- Parsing speed optimization
- Error handling improvements

---

## 📋 **NEXT STEPS**

1. **Analyze the AI model code** in the CV Analyser service
2. **Identify the parsing logic** causing these failures
3. **Implement rule-based fallbacks** for critical sections
4. **Test with multiple CV formats** to ensure robustness
5. **Consider model retraining** if parsing logic cannot be fixed

The current extraction quality makes the system **unsuitable for production use** until these core parsing issues are resolved.
