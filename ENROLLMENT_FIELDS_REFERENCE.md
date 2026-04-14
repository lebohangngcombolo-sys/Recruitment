# Enrollment Fields Reference

## All 14 Enrollment Fields & Storage Locations

### Personal Details (Step 1) - 6 Fields
| # | Field | Frontend Controller | Database Column | Type | CV Analysis Source |
|---|-------|---------------------|-----------------|------|-------------------|
| 1 | **Full Name** | `nameController` | `full_name` | VARCHAR(150) | `personal.full_name` |
| 2 | **Phone** | `phoneController` | `phone` | VARCHAR(50) | `personal.phone` |
| 3 | **Address** | `addressController` | `address` | VARCHAR(250) | `personal.address` |
| 4 | **Date of Birth** | `dobController` | `dob` | DATE | `personal.dob` |
| 5 | **LinkedIn** | `linkedinController` | `linkedin` | VARCHAR(250) | `personal.linkedin` |
| 6 | **Gender** | `selectedGender` | `gender` | VARCHAR(50) | `personal.gender` |

### Education (Step 2) - 3 Fields
| # | Field | Frontend Controller | Database Column | Type | CV Analysis Source |
|---|-------|---------------------|-----------------|------|-------------------|
| 7 | **Education Level** | `educationController` | `education_level` 🆕 | VARCHAR(100) | `education[0].degree` |
| 8 | **University/College** | `universityController` | `university` 🆕 | VARCHAR(150) | `education[0].institution` |
| 9 | **Graduation Year** | `graduationYearController` | `graduation_year` 🆕 | VARCHAR(4) | `education[0].year` |

**Note:** Also stored in `education` JSON array for full history

### Skills & Certifications (Step 3) - 3 Fields
| # | Field | Frontend Controller | Database Column | Type | CV Analysis Source |
|---|-------|---------------------|-----------------|------|-------------------|
| 10 | **Skills** | `skillsController` | `skills` | JSON array | `skills` (list) |
| 11 | **Certifications** | `certificationsController` | `certifications` | JSON array | `certifications` (list) |
| 12 | **Languages** | `languagesController` | `languages` | JSON array | `languages` (list) |

### Work Experience (Step 4) - 3 Fields
| # | Field | Frontend Controller | Database Column | Type | CV Analysis Source |
|---|-------|---------------------|-----------------|------|-------------------|
| 13 | **Previous Companies** | `previousCompaniesController` | `previous_companies` 🆕 | TEXT | `experience[].company` (joined) |
| 14 | **Position/Title** | `positionController` | `title` | VARCHAR(100) | `experience[0].title` |
| 15 | **Work Experience** | `experienceController` | `experience_summary` 🆕 | TEXT | `experience[].description` (joined) |

**Note:** Also stored in `work_experience` JSON array for full history

---

## 🆕 New Columns Summary (5 Added)

| Column | Purpose | Example Value |
|--------|---------|---------------|
| `education_level` | Highest degree for quick display | "Bachelor's Degree" |
| `university` | Primary institution | "University of Cape Town" |
| `graduation_year` | Year graduated | "2020" |
| `previous_companies` | All employers (comma-separated) | "Google, Microsoft, Amazon" |
| `experience_summary` | All job descriptions (joined) | "Built search features...\n\nDeveloped cloud tools..." |

---

## JSON Fields (Complex Data)

| Field | Type | Contents |
|-------|------|----------|
| `education` | JSON array | Full education history: `[{level, institution, graduation_year}, ...]` |
| `skills` | JSON array | All skills: `["Python", "React", "AWS", ...]` |
| `work_experience` | JSON array | Full job history: `[{position, company, description, period}, ...]` |
| `certifications` | JSON array | All certifications: `["AWS Certified", "PMP", ...]` |
| `languages` | JSON array | All languages: `["English", "Afrikaans", ...]` |

---

## API Response Example

```json
{
  "id": 123,
  "full_name": "John Doe",
  "phone": "+27 82 123 4567",
  "address": "Cape Town, South Africa",
  "dob": "1995-03-15",
  "linkedin": "https://linkedin.com/in/johndoe",
  "gender": "Male",
  
  "education_level": "Bachelor's Degree",
  "university": "University of Cape Town",
  "graduation_year": "2020",
  
  "skills": ["Python", "React", "AWS", "SQL"],
  "certifications": ["AWS Certified Developer"],
  "languages": ["English", "Afrikaans"],
  
  "previous_companies": "Google, Microsoft",
  "title": "Senior Software Engineer",
  "experience_summary": "Built search features for Google...\n\nDeveloped Azure tools at Microsoft...",
  
  "education": [
    {"level": "Bachelor's", "institution": "UCT", "graduation_year": "2020"},
    {"level": "Matric", "institution": "Grey High", "graduation_year": "2015"}
  ],
  "work_experience": [
    {"position": "Senior Engineer", "company": "Google", "description": "Built search..."},
    {"position": "Developer", "company": "Microsoft", "description": "Azure tools..."}
  ]
}
```

---

## Frontend to Backend Mapping

### Enrollment Form Submission
```dart
// Flutter form data
{
  "full_name": nameController.text,           // → full_name column
  "phone": phoneController.text,              // → phone column
  "address": addressController.text,          // → address column
  "dob": dobController.text,                  // → dob column
  "linkedin": linkedinController.text,        // → linkedin column
  "gender": selectedGender,                   // → gender column
  
  "education_level": educationController.text,    // → education_level column 🆕
  "university": universityController.text,        // → university column 🆕
  "graduation_year": graduationYearController.text, // → graduation_year column 🆕
  
  "skills": skillsController.text.split(','), // → skills JSON
  "certifications": certificationsController.text.split(','), // → certifications JSON
  "languages": languagesController.text.split(','), // → languages JSON
  
  "previous_companies": previousCompaniesController.text, // → previous_companies column 🆕
  "position": positionController.text,        // → title column
  "experience_summary": experienceController.text, // → experience_summary column 🆕
}
```

---

## Quick Reference: Field Count

| Category | Simple Columns | JSON Fields | Total |
|----------|---------------|-------------|-------|
| Personal | 6 | 0 | 6 |
| Education | 3 (NEW) | 1 | 3+ |
| Skills | 0 | 3 | 3 |
| Experience | 3 (2 NEW) | 1 | 3+ |
| **TOTAL** | **12** | **5** | **14+** |

*Note: JSON fields contain multiple entries (education history, all jobs, all skills)*
