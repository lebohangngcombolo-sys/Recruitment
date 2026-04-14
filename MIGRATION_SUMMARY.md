# Database Migration Summary: Enrollment Autofill Columns

## Overview
Added 5 new individual columns to the `candidates` table to make the autofill process easier and enable database-level validation for frequently accessed enrollment fields.

## New Columns Added

| Column | Type | Purpose | Populated From |
|--------|------|---------|----------------|
| `education_level` | VARCHAR(100) | Highest degree achieved (e.g., "Bachelor's Degree") | `education[0].degree` |
| `university` | VARCHAR(150) | University/college name | `education[0].institution` |
| `graduation_year` | VARCHAR(4) | Year of graduation (e.g., "2020") | `education[0].graduation_year` |
| `previous_companies` | TEXT | Comma-separated list of employers | `work_experience[].company` |
| `experience_summary` | TEXT | Aggregated work experience descriptions | `work_experience[].description` |

## Files Modified

### 1. Database Model (`server/app/models.py`)
- **Lines 402-408**: Added 5 new column definitions to `Candidate` class
- **Lines 464-469**: Added new fields to `to_dict()` method for API responses

### 2. Enrollment Service (`server/app/services/enrollment_service.py`)
- **Lines 28-51**: Added new fields to `SIMPLE_FIELDS` set
- **Lines 325**: Added `education_level` mapping from CV analysis
- **Lines 354-358**: Changed `experience` to `experience_summary` for consistency

### 3. CV Mapper (`server/app/services/cv_to_candidate_mapper.py`)
- **Lines 17-19**: Added new fields to `CANDIDATE_SIMPLE_FIELDS`
- **Lines 126-165**: Added logic to extract and populate new columns from CV analysis data

### 4. Enrollment Schema (`server/app/utils/enrollment_schema.py`)
- **Lines 21-26**: Added Marshmallow field definitions for validation

### 5. Migration Script (`server/migrations/add_enrollment_autofill_columns.py`)
- Created new migration script to add columns to existing database

## How It Works

### Data Flow
1. **CV Upload**: User uploads CV during enrollment
2. **CV Analysis**: CV Analyser extracts structured data (education, experience, skills, etc.)
3. **Mapping**: Server maps structured data to new columns:
   - First education entry → `education_level`, `university`, `graduation_year`
   - All work experience entries → `previous_companies` (deduplicated), `experience_summary` (aggregated)
4. **Storage**: Data saved to both new columns AND existing JSON arrays (for backward compatibility)
5. **API Response**: Frontend receives data via `to_dict()` which now includes new fields

### Example
```python
# CV Analysis Result
{
  "education": [{"degree": "Bachelor's", "institution": "UCT", "year": "2020"}],
  "work_experience": [
    {"company": "Google", "description": "Built search features"},
    {"company": "Microsoft", "description": "Developed Azure tools"}
  ]
}

# Maps to:
{
  "education_level": "Bachelor's",
  "university": "UCT", 
  "graduation_year": "2020",
  "previous_companies": "Google, Microsoft",
  "experience_summary": "Built search features\n\nDeveloped Azure tools"
}
```

## Migration Steps

1. **Run Migration**:
   ```bash
   cd server
   python migrations/add_enrollment_autofill_columns.py
   ```

2. **Rollback (if needed)**:
   ```bash
   python migrations/add_enrollment_autofill_columns.py --rollback
   ```

3. **Verify**: Check that new columns exist:
   ```sql
   \d candidates
   ```

## Benefits

✅ **Easier Autofill**: Direct column access instead of parsing JSON
✅ **Database Validation**: Can add CHECK constraints (e.g., graduation_year format)
✅ **Better Queries**: Can filter/sort by these fields in SQL
✅ **Backward Compatible**: JSON arrays still exist for full history
✅ **Performance**: Faster queries for individual fields

## Testing Checklist

- [ ] Run migration script successfully
- [ ] Upload CV and verify all 5 new fields populate
- [ ] Edit fields in enrollment form and verify updates save
- [ ] Check API response includes new fields in `/api/auth/me`
- [ ] Verify backward compatibility with existing candidates
