"""
Profile Monitoring Service
Implements comprehensive monitoring and analytics for the profile system
Based on the detailed analysis requirements
"""

import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from dataclasses import dataclass
from collections import defaultdict, deque
import json

logger = logging.getLogger(__name__)


@dataclass
class ProfileMetrics:
    """Profile system metrics data structure"""
    total_profiles: int = 0
    complete_profiles: int = 0
    incomplete_profiles: int = 0
    avg_completion_percentage: float = 0.0
    profile_updates_today: int = 0
    file_uploads_today: int = 0
    validation_errors_today: int = 0
    avg_update_time_ms: float = 0.0
    cache_hit_rate: float = 0.0
    active_users_today: int = 0


class ProfilePerformanceTracker:
    """Track profile system performance metrics"""
    
    def __init__(self):
        self.update_times = deque(maxlen=1000)  # Last 1000 update times
        self.validation_errors = defaultdict(int)
        self.cache_hits = 0
        self.cache_misses = 0
        self.file_uploads = defaultdict(int)
        self.profile_updates = defaultdict(int)
        self.active_users = set()
        
    def record_update_time(self, duration_ms: float):
        """Record profile update duration"""
        self.update_times.append(duration_ms)
    
    def record_validation_error(self, error_type: str):
        """Record validation error"""
        self.validation_errors[error_type] += 1
    
    def record_cache_hit(self):
        """Record cache hit"""
        self.cache_hits += 1
    
    def record_cache_miss(self):
        """Record cache miss"""
        self.cache_misses += 1
    
    def record_file_upload(self, file_type: str, size_mb: float):
        """Record file upload"""
        self.file_uploads[file_type] += 1
    
    def record_profile_update(self, user_id: int):
        """Record profile update"""
        today = datetime.now().strftime('%Y-%m-%d')
        self.profile_updates[today] += 1
        self.active_users.add(user_id)
    
    def get_average_update_time(self) -> float:
        """Get average update time in milliseconds"""
        if not self.update_times:
            return 0.0
        return sum(self.update_times) / len(self.update_times)
    
    def get_cache_hit_rate(self) -> float:
        """Get cache hit rate as percentage"""
        total = self.cache_hits + self.cache_misses
        if total == 0:
            return 0.0
        return (self.cache_hits / total) * 100
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """Get comprehensive metrics summary"""
        return {
            "performance": {
                "avg_update_time_ms": self.get_average_update_time(),
                "cache_hit_rate": self.get_cache_hit_rate(),
                "total_updates_tracked": len(self.update_times)
            },
            "errors": dict(self.validation_errors),
            "file_uploads": dict(self.file_uploads),
            "profile_updates": dict(self.profile_updates),
            "active_users_count": len(self.active_users),
            "cache_stats": {
                "hits": self.cache_hits,
                "misses": self.cache_misses,
                "total_requests": self.cache_hits + self.cache_misses
            }
        }


class ProfileAnalyticsService:
    """Comprehensive profile analytics service"""
    
    def __init__(self, db_session):
        self.db_session = db_session
        self.performance_tracker = ProfilePerformanceTracker()
        
    def get_profile_metrics(self, days: int = 30) -> ProfileMetrics:
        """Get comprehensive profile metrics"""
        try:
            from app.models import User, Candidate, ProfilePicture
            
            # Calculate date range
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=days)
            
            # Get profile statistics
            total_candidates = self.db_session.query(Candidate).count()
            
            # Calculate completion statistics
            completion_stats = self._calculate_completion_stats()
            
            # Get today's activity
            today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            
            profile_updates_today = self.db_session.query(Candidate)\
                .filter(Candidate.updated_at >= today)\
                .count()
            
            file_uploads_today = self.db_session.query(ProfilePicture)\
                .filter(ProfilePicture.created_at >= today)\
                .count()
            
            # Get validation errors from performance tracker
            validation_errors_today = sum(
                count for error_type, count in self.performance_tracker.validation_errors.items()
                if error_type.startswith(f"{datetime.now().strftime('%Y-%m-%d')}_")
            )
            
            # Get active users today
            active_users_today = len(self.performance_tracker.active_users)
            
            return ProfileMetrics(
                total_profiles=total_candidates,
                complete_profiles=completion_stats['complete'],
                incomplete_profiles=completion_stats['incomplete'],
                avg_completion_percentage=completion_stats['average'],
                profile_updates_today=profile_updates_today,
                file_uploads_today=file_uploads_today,
                validation_errors_today=validation_errors_today,
                avg_update_time_ms=self.performance_tracker.get_average_update_time(),
                cache_hit_rate=self.performance_tracker.get_cache_hit_rate(),
                active_users_today=active_users_today
            )
            
        except Exception as e:
            logger.error(f"Error getting profile metrics: {e}")
            return ProfileMetrics()
    
    def _calculate_completion_stats(self) -> Dict[str, Any]:
        """Calculate profile completion statistics"""
        try:
            from app.models import Candidate
            from app.services.profile_validation_service import ProfileCompletionCalculator
            
            candidates = self.db_session.query(Candidate).all()
            
            if not candidates:
                return {'complete': 0, 'incomplete': 0, 'average': 0.0}
            
            completion_percentages = []
            complete_count = 0
            
            for candidate in candidates:
                candidate_dict = candidate.to_dict()
                completion_data = ProfileCompletionCalculator.calculate_completion(candidate_dict)
                completion_percentages.append(completion_data['overall_percentage'])
                
                if completion_data['overall_percentage'] >= 80:
                    complete_count += 1
            
            average_completion = sum(completion_percentages) / len(completion_percentages) if completion_percentages else 0.0
            
            return {
                'complete': complete_count,
                'incomplete': len(candidates) - complete_count,
                'average': average_completion
            }
            
        except Exception as e:
            logger.error(f"Error calculating completion stats: {e}")
            return {'complete': 0, 'incomplete': 0, 'average': 0.0}
    
    def get_field_completion_breakdown(self) -> Dict[str, Any]:
        """Get completion breakdown by field"""
        try:
            from app.models import Candidate
            
            candidates = self.db_session.query(Candidate).all()
            
            field_stats = {
                'full_name': 0,
                'phone': 0,
                'title': 0,
                'bio': 0,
                'linkedin': 0,
                'github': 0,
                'portfolio': 0,
                'profile_picture': 0,
                'skills': 0,
                'education': 0,
                'work_experience': 0,
                'certifications': 0,
                'languages': 0
            }
            
            total_candidates = len(candidates)
            if total_candidates == 0:
                return field_stats
            
            for candidate in candidates:
                if candidate.full_name and candidate.full_name.strip():
                    field_stats['full_name'] += 1
                if candidate.phone and candidate.phone.strip():
                    field_stats['phone'] += 1
                if candidate.title and candidate.title.strip():
                    field_stats['title'] += 1
                if candidate.bio and candidate.bio.strip():
                    field_stats['bio'] += 1
                if candidate.linkedin and candidate.linkedin.strip():
                    field_stats['linkedin'] += 1
                if candidate.github and candidate.github.strip():
                    field_stats['github'] += 1
                if candidate.portfolio and candidate.portfolio.strip():
                    field_stats['portfolio'] += 1
                if candidate.profile_picture and candidate.profile_picture.strip():
                    field_stats['profile_picture'] += 1
                
                # JSON fields
                if candidate.skills and len(candidate.skills) > 0:
                    field_stats['skills'] += 1
                if candidate.education and len(candidate.education) > 0:
                    field_stats['education'] += 1
                if candidate.work_experience and len(candidate.work_experience) > 0:
                    field_stats['work_experience'] += 1
                if candidate.certifications and len(candidate.certifications) > 0:
                    field_stats['certifications'] += 1
                if candidate.languages and len(candidate.languages) > 0:
                    field_stats['languages'] += 1
            
            # Convert to percentages
            for field in field_stats:
                field_stats[field] = (field_stats[field] / total_candidates) * 100
            
            return field_stats
            
        except Exception as e:
            logger.error(f"Error getting field completion breakdown: {e}")
            return {}
    
    def get_activity_timeline(self, days: int = 7) -> List[Dict[str, Any]]:
        """Get activity timeline for the last N days"""
        try:
            from app.models import Candidate, ProfilePicture
            
            timeline = []
            end_date = datetime.utcnow()
            
            for i in range(days):
                date = end_date - timedelta(days=i)
                day_start = date.replace(hour=0, minute=0, second=0, microsecond=0)
                day_end = date.replace(hour=23, minute=59, second=59, microsecond=999999)
                
                profile_updates = self.db_session.query(Candidate)\
                    .filter(Candidate.updated_at.between(day_start, day_end))\
                    .count()
                
                file_uploads = self.db_session.query(ProfilePicture)\
                    .filter(ProfilePicture.created_at.between(day_start, day_end))\
                    .count()
                
                timeline.append({
                    'date': day_start.strftime('%Y-%m-%d'),
                    'profile_updates': profile_updates,
                    'file_uploads': file_uploads,
                    'total_activity': profile_updates + file_uploads
                })
            
            return list(reversed(timeline))  # Most recent first
            
        except Exception as e:
            logger.error(f"Error getting activity timeline: {e}")
            return []
    
    def get_validation_error_analysis(self) -> Dict[str, Any]:
        """Get validation error analysis"""
        try:
            error_analysis = {
                'total_errors': sum(self.performance_tracker.validation_errors.values()),
                'error_types': dict(self.performance_tracker.validation_errors),
                'most_common_errors': [],
                'error_trends': {}
            }
            
            # Get most common errors
            sorted_errors = sorted(
                self.performance_tracker.validation_errors.items(),
                key=lambda x: x[1],
                reverse=True
            )
            
            error_analysis['most_common_errors'] = [
                {'type': error_type, 'count': count}
                for error_type, count in sorted_errors[:10]
            ]
            
            # Calculate error trends (last 7 days)
            for i in range(7):
                date = datetime.now() - timedelta(days=i)
                date_key = date.strftime('%Y-%m-%d')
                day_errors = sum(
                    count for error_type, count in self.performance_tracker.validation_errors.items()
                    if error_type.startswith(date_key)
                )
                error_analysis['error_trends'][date_key] = day_errors
            
            return error_analysis
            
        except Exception as e:
            logger.error(f"Error getting validation error analysis: {e}")
            return {}
    
    def get_performance_report(self) -> Dict[str, Any]:
        """Get comprehensive performance report"""
        try:
            performance_report = {
                'update_performance': {
                    'avg_time_ms': self.performance_tracker.get_average_update_time(),
                    'median_time_ms': self._calculate_median_time(),
                    'p95_time_ms': self._calculate_percentile_time(95),
                    'p99_time_ms': self._calculate_percentile_time(99),
                    'total_updates': len(self.performance_tracker.update_times)
                },
                'cache_performance': {
                    'hit_rate': self.performance_tracker.get_cache_hit_rate(),
                    'total_requests': self.performance_tracker.cache_hits + self.performance_tracker.cache_misses,
                    'hits': self.performance_tracker.cache_hits,
                    'misses': self.performance_tracker.cache_misses
                },
                'file_upload_performance': dict(self.performance_tracker.file_uploads),
                'system_health': {
                    'status': 'healthy' if self._is_system_healthy() else 'degraded',
                    'issues': self._identify_performance_issues()
                }
            }
            
            return performance_report
            
        except Exception as e:
            logger.error(f"Error getting performance report: {e}")
            return {}
    
    def _calculate_median_time(self) -> float:
        """Calculate median update time"""
        if not self.performance_tracker.update_times:
            return 0.0
        
        sorted_times = sorted(self.performance_tracker.update_times)
        n = len(sorted_times)
        
        if n % 2 == 0:
            return (sorted_times[n//2 - 1] + sorted_times[n//2]) / 2
        else:
            return sorted_times[n//2]
    
    def _calculate_percentile_time(self, percentile: int) -> float:
        """Calculate percentile update time"""
        if not self.performance_tracker.update_times:
            return 0.0
        
        sorted_times = sorted(self.performance_tracker.update_times)
        index = int((percentile / 100) * len(sorted_times))
        return sorted_times[min(index, len(sorted_times) - 1)]
    
    def _is_system_healthy(self) -> bool:
        """Determine if system is healthy"""
        avg_time = self.performance_tracker.get_average_update_time()
        cache_hit_rate = self.performance_tracker.get_cache_hit_rate()
        
        # System is healthy if:
        # - Average update time is under 500ms
        # - Cache hit rate is above 70%
        # - No critical errors in last hour
        
        if avg_time > 500:
            return False
        
        if cache_hit_rate < 70 and (self.performance_tracker.cache_hits + self.performance_tracker.cache_misses) > 100:
            return False
        
        return True
    
    def _identify_performance_issues(self) -> List[str]:
        """Identify performance issues"""
        issues = []
        
        avg_time = self.performance_tracker.get_average_update_time()
        if avg_time > 500:
            issues.append(f"High average update time: {avg_time:.2f}ms")
        
        cache_hit_rate = self.performance_tracker.get_cache_hit_rate()
        if cache_hit_rate < 70 and (self.performance_tracker.cache_hits + self.performance_tracker.cache_misses) > 100:
            issues.append(f"Low cache hit rate: {cache_hit_rate:.1f}%")
        
        if len(self.performance_tracker.validation_errors) > 100:
            issues.append(f"High validation error count: {len(self.performance_tracker.validation_errors)}")
        
        return issues


class ProfileAlertService:
    """Alert service for profile system monitoring"""
    
    def __init__(self, analytics_service: ProfileAnalyticsService):
        self.analytics_service = analytics_service
        self.alert_thresholds = {
            'avg_update_time_ms': 500,
            'cache_hit_rate_min': 70,
            'validation_error_rate_max': 5,  # 5% of total updates
            'completion_rate_min': 60  # 60% of profiles should be >80% complete
        }
    
    def check_alerts(self) -> List[Dict[str, Any]]:
        """Check for system alerts"""
        alerts = []
        
        try:
            metrics = self.analytics_service.get_profile_metrics()
            performance_report = self.analytics_service.get_performance_report()
            
            # Check update time alert
            if metrics.avg_update_time_ms > self.alert_thresholds['avg_update_time_ms']:
                alerts.append({
                    'type': 'performance',
                    'severity': 'warning',
                    'message': f"High average update time: {metrics.avg_update_time_ms:.2f}ms",
                    'threshold': self.alert_thresholds['avg_update_time_ms'],
                    'current_value': metrics.avg_update_time_ms,
                    'timestamp': datetime.utcnow().isoformat()
                })
            
            # Check cache hit rate alert
            if metrics.cache_hit_rate < self.alert_thresholds['cache_hit_rate_min']:
                alerts.append({
                    'type': 'performance',
                    'severity': 'warning',
                    'message': f"Low cache hit rate: {metrics.cache_hit_rate:.1f}%",
                    'threshold': self.alert_thresholds['cache_hit_rate_min'],
                    'current_value': metrics.cache_hit_rate,
                    'timestamp': datetime.utcnow().isoformat()
                })
            
            # Check validation error rate
            total_updates = metrics.profile_updates_today
            validation_errors = metrics.validation_errors_today
            
            if total_updates > 0:
                error_rate = (validation_errors / total_updates) * 100
                if error_rate > self.alert_thresholds['validation_error_rate_max']:
                    alerts.append({
                        'type': 'quality',
                        'severity': 'warning',
                        'message': f"High validation error rate: {error_rate:.1f}%",
                        'threshold': self.alert_thresholds['validation_error_rate_max'],
                        'current_value': error_rate,
                        'timestamp': datetime.utcnow().isoformat()
                    })
            
            # Check profile completion rate
            if metrics.total_profiles > 0:
                completion_rate = (metrics.complete_profiles / metrics.total_profiles) * 100
                if completion_rate < self.alert_thresholds['completion_rate_min']:
                    alerts.append({
                        'type': 'engagement',
                        'severity': 'info',
                        'message': f"Low profile completion rate: {completion_rate:.1f}%",
                        'threshold': self.alert_thresholds['completion_rate_min'],
                        'current_value': completion_rate,
                        'timestamp': datetime.utcnow().isoformat()
                    })
            
            # Check system health
            system_health = performance_report.get('system_health', {})
            if system_health.get('status') == 'degraded':
                alerts.append({
                    'type': 'system',
                    'severity': 'critical',
                    'message': "System health is degraded",
                    'issues': system_health.get('issues', []),
                    'timestamp': datetime.utcnow().isoformat()
                })
            
        except Exception as e:
            logger.error(f"Error checking alerts: {e}")
            alerts.append({
                'type': 'system',
                'severity': 'critical',
                'message': f"Error checking system alerts: {str(e)}",
                'timestamp': datetime.utcnow().isoformat()
            })
        
        return alerts
    
    def send_alert_notification(self, alert: Dict[str, Any]):
        """Send alert notification (placeholder for actual implementation)"""
        logger.warning(f"PROFILE ALERT: {alert['message']}")
        
        # Implementation would integrate with notification service
        # - Email notifications
        # - Slack notifications
        # - SMS notifications for critical alerts
        # - Dashboard updates


# Global performance tracker instance
performance_tracker = ProfilePerformanceTracker()


def track_profile_performance(func):
    """Decorator to track profile operation performance"""
    def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            duration_ms = (time.time() - start_time) * 1000
            performance_tracker.record_update_time(duration_ms)
            return result
        except Exception as e:
            duration_ms = (time.time() - start_time) * 1000
            performance_tracker.record_update_time(duration_ms)
            
            # Record error type
            error_type = f"{datetime.now().strftime('%Y-%m-%d')}_{type(e).__name__}"
            performance_tracker.record_validation_error(error_type)
            
            raise
    
    return wrapper
