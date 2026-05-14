# FastAPI CV Analysis Service Integration

This document describes the integration of the external FastAPI CV analysis service to replace the Celery-based CV analysis system.

## Overview

The recruitment application now uses an external FastAPI service for CV analysis instead of the local Celery-based system. This change provides:

- **Scalability**: Offloads CV processing to a dedicated service
- **Maintainability**: Separates concerns between main app and CV analysis
- **Performance**: Asynchronous processing with polling mechanism
- **Accuracy**: Enhanced AI-powered analysis with confidence scoring

## Architecture Changes

### Before (Celery-based)
```
Flutter → Flask Upload → Cloudinary → CVAnalysis Record → Celery Task → AI Analysis → Database Update → HM UI
```

### After (FastAPI Service)
```
Flutter → Flask Upload → Cloudinary → CVAnalysis Record → FastAPI Service → Polling → Data Merge → Database Update → HM UI
```

## Key Components

### 1. Database Schema
- **New Column**: `cv_analyses.external_analysis_id` (String, nullable, indexed)
- **Indexes**: Added on `status` and `external_analysis_id` for efficient polling

### 2. External Service Client
- **File**: `app/services/analysis_service_client.py`
- **Methods**:
  - `submit_cv()` - Submit CV for analysis
  - `get_analysis_status()` - Check analysis status
  - `get_analysis_result()` - Fetch completed analysis

### 3. Background Polling
- **File**: `app/tasks/polling_tasks.py`
- **Schedule**: Every 2 minutes via Celery beat
- **Process**: Checks pending analyses and updates local database

### 4. Data Merger
- **File**: `app/services/data_merger.py`
- **Function**: `update_local_database()` - Merges external results
- **Confidence Threshold**: 90% for auto-filling candidate profiles

### 5. Updated Endpoints
- **Upload**: `/api/candidate/upload_resume/<id>` - Now submits to FastAPI service
- **HM Reviews**: `/api/admin/notification-preferences` - Handles new result format

## Configuration

Add these environment variables to your `.env`:

```bash
# FastAPI Analysis Service
ANALYSIS_SERVICE_URL=https://your-fastapi-service.com
ANALYSIS_SERVICE_API_KEY=your-secret-api-key
```

## API Contract

### Submit CV for Analysis
```http
POST /upload
Authorization: Bearer <api_key>
Content-Type: application/json

{
  "cv_url": "https://cloudinary.com/...",
  "job_description": "Job requirements..."
}

Response (202):
{
  "analysis_id": "uuid-string",
  "status": "submitted"
}
```

### Check Status
```http
GET /analyses/{analysis_id}/status
Authorization: Bearer <api_key>

Response:
{
  "analysis_id": "uuid-string",
  "status": "submitted|processing|completed|failed"
}
```

### Get Result
```http
GET /analyses/{analysis_id}/result
Authorization: Bearer <api_key>

Response:
{
  "match_analysis": {
    "overall_score": 85,
    "component_scores": {"skills": 90, "experience": 80},
    "evidence": {
      "skills": [{"skill": "Python", "confidence": 0.95}],
      "education": [{"institution": "MIT", "degree": "BS", "year": 2020, "confidence": 0.9}],
      "experience": [{"company": "ABC", "position": "Developer", "dates": "2019-2022", "confidence": 0.85}],
      "certifications": [{"name": "AWS Certified", "confidence": 0.9}],
      "languages": [{"language": "English", "confidence": 1.0}]
    },
    "missing_skills": ["AWS"],
    "suggestions": ["Highlight AWS experience"]
  }
}
```

## Data Flow

1. **CV Upload**: Candidate uploads CV via Flutter app
2. **Local Record**: Flask creates `CVAnalysis` record with status 'pending'
3. **External Submission**: CV and job description sent to FastAPI service
4. **Analysis ID**: External service returns `analysis_id` stored locally
5. **Background Polling**: Celery beat task checks status every 2 minutes
6. **Result Retrieval**: When completed, full analysis result fetched
7. **Data Merging**: Results merged into local database with confidence filtering
8. **UI Update**: HM reviews endpoint displays transformed data

## Candidate Profile Enrichment

The system automatically enriches candidate profiles with high-confidence extracted data:

- **Skills**: Added if confidence > 90% and not duplicate
- **Education**: Added if confidence > 90% and not duplicate
- **Experience**: Added if confidence > 90% and not duplicate
- **Certifications**: Added if confidence > 90% and not duplicate
- **Languages**: Added if confidence > 90% and not duplicate

## Backward Compatibility

- **Flutter UI**: No changes required - same API response format
- **Database Migration**: Backward compatible - new nullable column
- **Rollback Plan**: Legacy Celery task commented out for easy rollback

## Monitoring & Logging

### Key Metrics
- External service response times
- Analysis completion rates
- Polling task execution
- Data merge success/failure rates

### Log Messages
- CV submission to external service
- Polling task execution
- Data merge operations
- Error conditions and retries

## Testing

### Unit Tests
- Mock external service responses
- Test data merging logic with confidence thresholds
- Verify database updates

### Integration Tests
- End-to-end CV upload and analysis flow
- Error handling for service failures
- Polling mechanism verification

### Test Files
- `tests/test_analysis_service_integration.py`

## Deployment

### Steps
1. Run database migration: `flask db upgrade`
2. Deploy updated code with new services
3. Set environment variables for FastAPI service
4. Restart Celery workers with beat scheduler
5. Monitor initial polling cycles

### Rollback
1. Uncomment legacy `analyze_cv_task` in `cv_tasks.py`
2. Remove external service call from upload endpoint
3. Restore original endpoint response format
4. Restart services

## Troubleshooting

### Common Issues

1. **External Service Unavailable**
   - Check `ANALYSIS_SERVICE_URL` and `ANALYSIS_SERVICE_API_KEY`
   - Verify network connectivity
   - Check service logs

2. **Polling Not Working**
   - Ensure Celery beat is running
   - Check beat schedule configuration
   - Verify task registration

3. **Data Not Merging**
   - Check confidence thresholds in data merger
   - Verify external result format
   - Review database constraints

4. **UI Not Updating**
   - Check HM reviews endpoint transformation
   - Verify response format matches Flutter expectations
   - Review browser console for errors

### Debug Commands

```bash
# Check Celery beat schedule
celery -A celery_worker inspect scheduled

# Check active tasks
celery -A celery_worker inspect active

# Run polling task manually
celery -A celery_worker call app.tasks.polling_tasks.poll_cv_analysis_results
```

## Performance Considerations

- **Polling Interval**: 2 minutes balances responsiveness and load
- **Batch Size**: Limited to 50 analyses per polling cycle
- **Timeouts**: 30s for submission, 10s for status checks
- **Retries**: 3 retries with exponential backoff

## Security

- **API Keys**: Stored securely in environment variables
- **HTTPS**: Required for production external service URLs
- **Authentication**: Bearer token authentication for external service
- **Data Validation**: All external data validated before database updates

## Future Enhancements

1. **Webhook Support**: Replace polling with webhook callbacks
2. **Confidence Tuning**: Adjustable confidence thresholds per field
3. **Bulk Processing**: Support for batch CV analysis
4. **Caching**: Cache external service responses
5. **Circuit Breaker**: Implement fallback for service outages
