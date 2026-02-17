import 'app_config.dart';

class ApiEndpoints {
  // ------------------- Base URLs (driven by AppConfig / --dart-define) -------------------
  static String get authBase => "${AppConfig.apiBase}/api/auth";
  static String get candidateBase => "${AppConfig.apiBase}/api/candidate";
  static String get adminBase => "${AppConfig.apiBase}/api/admin";
  /// AI chat and CV parse (backend blueprint is at /api/ai)
  static String get chatbotBase => "${AppConfig.apiBase}/api/ai";
  static String get publicBase => "${AppConfig.publicApiBase}/api/public";
  static String get analyticsBase => "${AppConfig.apiBase}/api/analytics";

  // NEW: Offer management base URL (matches your Flask blueprint)
  static String get offerBase => "${AppConfig.apiBase}/api/offer";

  // WebSocket URL (for real-time chat) derived from API base (ws/wss)
  static String get webSocketUrl => AppConfig.apiBase.startsWith('https')
      ? AppConfig.apiBase.replaceFirst('https', 'wss')
      : AppConfig.apiBase.replaceFirst('http', 'ws');

  // Chat base URL
  static String get chatBase => "${AppConfig.apiBase}/api/chat";

  // ------------------- Auth -------------------
  static final register = "$authBase/register";
  static final verify = "$authBase/verify";
  static final login = "$authBase/login";
  static final logout = "$authBase/logout";
  static final forgotPassword = "$authBase/forgot-password";
  static final resetPassword = "$authBase/reset-password";
  static final changePassword = "$authBase/change-password";
  static final currentUser = "$authBase/me";
  static final adminEnroll = "$authBase/admin-enroll";
  static final firebaseLogin = "$authBase/firebase-login";

  // ------------------- OAuth (UPDATED FOR SUPABASE) -------------------
  static final googleOAuth = "$authBase/google";
  static final githubOAuth = "$authBase/github";
  static final supabaseCallback = "$authBase/callback"; // New unified callback

  // ------------------- SSO -------------------
  static final ssoLogout = "$authBase/sso/logout"; // <-- ADDED

  // ------------------- MFA (UPDATED TO MATCH BACKEND) -------------------
  static final enableMfa = "$authBase/mfa/enable"; // POST - Initiate MFA setup
  static final verifyMfaSetup = "$authBase/mfa/verify"; // POST - Verify MFA setup
  static final mfaLogin = "$authBase/mfa/login"; // POST - Verify MFA during login
  static final disableMfa = "$authBase/mfa/disable"; // POST - Disable MFA
  static final mfaStatus = "$authBase/mfa/status"; // GET - Get MFA status
  static final backupCodes = "$authBase/mfa/backup-codes"; // GET - Get backup codes
  static final regenerateBackupCodes =
      "$authBase/mfa/regenerate-backup-codes"; // POST - Regenerate backup codes
  static final String parserCV = "$authBase/cv/parse"; // POST Multipart

  // ------------------- Public (no auth) -------------------
  static final getPublicJobs = "$publicBase/jobs";

  // ------------------- Candidate -------------------
  static final enrollment = "$candidateBase/enrollment";
  static final applyJob = "$candidateBase/apply";
  static final submitAssessment = "$candidateBase/applications";
  static final uploadResume = "$candidateBase/upload_resume";
  static final getApplications = "$candidateBase/applications";
  static final getAvailableJobs = "$candidateBase/jobs";
  static final saveDraft = "$candidateBase/apply/save_draft";
  static final getDrafts = "$candidateBase/applications/drafts";
  static final submitDraft = "$candidateBase/applications/submit_draft";

  // ==================== RECRUITMENT PIPELINE ENDPOINTS ====================

  // ------------------- Pipeline Statistics -------------------
  static final getPipelineStats = "$adminBase/pipeline/stats";
  static final getPipelineQuickStats = "$adminBase/pipeline/quick-stats";
  static final getPipelineStagesCount = "$adminBase/pipeline/stages/count";

  // ------------------- Applications with Filters -------------------
  static final getFilteredApplications = "$adminBase/applications/filtered";

  // Enhanced existing endpoints with query params
  static String getApplicationsByStatus(String status) =>
      "$adminBase/applications/filtered?status=$status";

  static String getApplicationsByJob(int jobId) =>
      "$adminBase/applications/filtered?job_id=$jobId";

  static String searchApplications(String query) =>
      "$adminBase/applications/filtered?search=$query";

  // ------------------- Jobs with Statistics -------------------
  static final getJobsWithStats = "$adminBase/jobs/with-stats";

  // ------------------- Interviews by Timeframe -------------------
  static String getInterviewsByTimeframe(String timeframe) =>
      "$adminBase/interviews/dashboard/$timeframe"; // today, upcoming, past, week, month

  // Alias for compatibility
  static final getTodaysInterviews = "$adminBase/interviews/dashboard/today";
  static final getUpcomingInterviews = "$adminBase/interviews/dashboard/upcoming";
  static final getPastInterviews = "$adminBase/interviews/dashboard/past";

  // ------------------- Update Application Status -------------------
  static String updateApplicationStatus(int applicationId) =>
      "$adminBase/applications/$applicationId/status";

  // ------------------- Global Search -------------------
  static String searchAll(String query) => "$adminBase/search?q=$query";

  // ------------------- Admin / Hiring Manager -------------------
  static final adminJobs = "$adminBase/jobs";
  static String getJobById(int id) => "$adminBase/jobs/$id";
  static final createJob = "$adminBase/jobs";
  static String updateJob(int id) => "$adminBase/jobs/$id";
  static String deleteJob(int id) => "$adminBase/jobs/$id";

  // Add these if not already present
  static String getJobDetailed(int id) => "$adminBase/jobs/$id/detailed";
  static String restoreJob(int id) => "$adminBase/jobs/$id/restore";
  static String getJobActivity(int id) => "$adminBase/jobs/$id/activity";
  static String getJobApplications(int id) =>
      "$adminBase/jobs/$id/applications";
  static String getJobStats = "$adminBase/jobs/stats";
  static final viewCandidates = "$adminBase/candidates";
  static String getApplicationById(int id) => "$adminBase/applications/$id";
  static String shortlistCandidates(int jobId) =>
      "$adminBase/jobs/$jobId/shortlist";
  static final scheduleInterview = "$adminBase/interviews";
  static final getAllInterviews = "$adminBase/interviews";
  static String cancelInterview(int interviewId) =>
      "$adminBase/interviews/cancel/$interviewId";
  static final getNotifications = "$adminBase/notifications";
  static final auditLogs = "$adminBase/audits";
  static final parseResume = "$adminBase/cv/parse";
  static final cvReviews = "$adminBase/cv-reviews";
  static final getUsers = "$adminBase/users";

  // ==================== INTERVIEW LIFECYCLE ENHANCEMENTS ====================

  // ------------------- Interview Status Updates -------------------
  /// PATCH – Update interview status (completed, no_show, cancelled_by_candidate, etc.)
  static String updateInterviewStatus(int interviewId) =>
      "$adminBase/interviews/$interviewId/status";

  /// GET – Get all interviews for a candidate (existing)
  static String getCandidateInterviews(int candidateId) =>
      "$adminBase/interviews?candidate_id=$candidateId";

  /// PUT/PATCH – Reschedule an interview
  static String rescheduleInterview(int interviewId) =>
      "$adminBase/interviews/reschedule/$interviewId";

  /// DELETE – Cancel an interview
  static String cancelSingleInterview(int interviewId) =>
      "$adminBase/interviews/cancel/$interviewId";

  // ------------------- Interview Feedback -------------------
  /// POST – Submit interview feedback
  static String submitInterviewFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback";

  /// GET – Get all feedback for an interview
  static String getInterviewFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback";

  /// POST – Request feedback from interviewer (email trigger)
  static String requestFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback/request";

  /// GET – Get feedback summary for an interview
  static String getFeedbackSummary(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback/summary";

  // ------------------- Interview Reminders -------------------
  /// POST – Schedule automated reminders for interviews
  static final scheduleInterviewReminders =
      "$adminBase/interviews/reminders/schedule";

  /// GET – Get all reminders for an interview
  static String getInterviewReminders(int interviewId) =>
      "$adminBase/interviews/$interviewId/reminders";

  /// POST – Send immediate reminder (ad-hoc)
  static String sendImmediateReminder(int interviewId) =>
      "$adminBase/interviews/$interviewId/reminders/send";

  /// DELETE – Cancel a scheduled reminder
  static String cancelInterviewReminder(int reminderId) =>
      "$adminBase/interviews/reminders/$reminderId";

  // ------------------- Interview Analytics -------------------
  /// GET – Get interview statistics and metrics
  static final getInterviewAnalytics = "$adminBase/interviews/analytics";

  /// GET – Get no-show statistics
  static final getNoShowAnalytics = "$adminBase/interviews/analytics/no-shows";

  /// GET – Get feedback completion rates
  static final getFeedbackAnalytics =
      "$adminBase/interviews/analytics/feedback";

  /// GET – Get interviewer performance metrics
  static final getInterviewerAnalytics =
      "$adminBase/interviews/analytics/interviewers";

  // ------------------- Interview Notes -------------------
  /// POST – Add notes to an interview
  static String addInterviewNotes(int interviewId) =>
      "$adminBase/interviews/$interviewId/notes";

  /// GET – Get all notes for an interview
  static String getInterviewNotes(int interviewId) =>
      "$adminBase/interviews/$interviewId/notes";

  /// PUT – Update interview notes
  static String updateInterviewNotes(int noteId) =>
      "$adminBase/interviews/notes/$noteId";

  /// DELETE – Delete interview notes
  static String deleteInterviewNotes(int noteId) =>
      "$adminBase/interviews/notes/$noteId";

  // ------------------- Interview Workflow -------------------
  /// POST – Move interview to next stage
  static String moveInterviewToNextStage(int interviewId) =>
      "$adminBase/interviews/$interviewId/workflow/next";

  /// POST – Move interview to previous stage
  static String moveInterviewToPreviousStage(int interviewId) =>
      "$adminBase/interviews/$interviewId/workflow/previous";

  /// GET – Get interview workflow stages
  static final getInterviewWorkflowStages =
      "$adminBase/interviews/workflow/stages";

  // ------------------- Bulk Interview Operations -------------------
  /// POST – Bulk update interview statuses
  static final bulkUpdateInterviewStatus = "$adminBase/interviews/bulk/status";

  /// POST – Bulk schedule reminders
  static final bulkScheduleReminders = "$adminBase/interviews/bulk/reminders";

  /// POST – Bulk request feedback
  static final bulkRequestFeedback =
      "$adminBase/interviews/bulk/feedback/request";

  // ------------------- Interview Templates -------------------
  /// GET – Get all interview templates
  static final getInterviewTemplates = "$adminBase/interviews/templates";

  /// GET – Get specific interview template
  static String getInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  /// POST – Create new interview template
  static final createInterviewTemplate = "$adminBase/interviews/templates";

  /// PUT – Update interview template
  static String updateInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  /// DELETE – Delete interview template
  static String deleteInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  // ------------------- Candidate Availability -------------------
  /// GET – Get candidate availability
  static String getCandidateAvailability(int candidateId) =>
      "$adminBase/candidates/$candidateId/availability";

  /// POST – Set candidate availability
  static String setCandidateAvailability(int candidateId) =>
      "$adminBase/candidates/$candidateId/availability";

  /// POST – Check interview scheduling conflicts
  static final checkSchedulingConflicts =
      "$adminBase/interviews/conflict-check";

  // ------------------- Interview Dashboard -------------------
  /// GET – Get interviews requiring action
  static final getInterviewsRequiringAction =
      "$adminBase/interviews/dashboard/action-required";

  // ------------------- Shared Notes & Meetings -------------------
  static final createNote = "$adminBase/shared-notes";
  static final getNotes = "$adminBase/shared-notes";
  static String getNoteById(int id) => "$adminBase/shared-notes/$id";
  static String updateNote(int id) => "$adminBase/shared-notes/$id";
  static String deleteNote(int id) => "$adminBase/shared-notes/$id";

  static final createMeeting = "$adminBase/meetings";
  static final getMeetings = "$adminBase/meetings";
  static String getMeetingById(int id) => "$adminBase/meetings/$id";
  static String updateMeeting(int id) => "$adminBase/meetings/$id";
  static String deleteMeeting(int id) => "$adminBase/meetings/$id";
  static String cancelMeeting(int id) => "$adminBase/meetings/$id/cancel";
  static final getUpcomingMeetings = "$adminBase/meetings/upcoming";

  // ------------------- Interview Calendar (Google Calendar) -------------------
  /// GET – Sync & compare upcoming interviews with Google Calendar
  static final syncInterviewCalendar = "$adminBase/interviews/calendar/sync";

  /// POST – Sync a single interview to Google Calendar
  static String syncSingleInterviewCalendar(int interviewId) =>
      "$adminBase/interviews/$interviewId/calendar/sync";

  /// POST – Bulk sync multiple interviews
  static final bulkSyncInterviewCalendar =
      "$adminBase/interviews/calendar/bulk-sync";

  /// GET – Get calendar status for a specific interview
  static String getInterviewCalendarStatus(int interviewId) =>
      "$adminBase/interviews/$interviewId/calendar/status";

  // ------------------- AI Chatbot -------------------
  static final parseCV = "$chatbotBase/parse_cv";
  /// Backend: POST /api/ai/chat with body { "message": "..." }
  static final askBot = "$chatbotBase/chat";

  // ==================== CHAT FEATURE ENDPOINTS ====================

  // Thread Management
  static final getChatThreads = "$chatBase/threads";
  static final createChatThread = "$chatBase/threads";
  static String getChatThread(int id) => "$chatBase/threads/$id";

  // Messages
  static String getChatMessages(int threadId) =>
      "$chatBase/threads/$threadId/messages";
  static String sendChatMessage(int threadId) =>
      "$chatBase/threads/$threadId/messages";
  static String markMessagesAsRead(int threadId) =>
      "$chatBase/threads/$threadId/mark-read";

  // Search
  static final searchChatMessages = "$chatBase/search";

  // Presence
  static final updatePresence = "$chatBase/presence";

  // Typing Indicator
  static String setTypingStatus(int threadId) =>
      "$chatBase/threads/$threadId/typing";

  // Entity-specific Chats
  static String getEntityChat(String entityType, String entityId) =>
      "$chatBase/entity/$entityType/$entityId";

  // Helper methods for specific chat types
  static String getCandidateChat(int candidateId) =>
      "$chatBase/entity/candidate/$candidateId";
  static String getRequisitionChat(int requisitionId) =>
      "$chatBase/entity/requisition/$requisitionId";

  // ==================== OFFER ENDPOINTS (Flask blueprint routes) ====================

  // Offer endpoints - exactly matching your Flask routes
  static final draftOffer = "$offerBase/"; // POST - Draft offer
  static String reviewOffer(int offerId) =>
      "$offerBase/$offerId/review"; // POST - Review offer
  static String approveOffer(int offerId) =>
      "$offerBase/$offerId/approve"; // POST - Approve offer
  static String signOffer(int offerId) =>
      "$offerBase/$offerId/sign"; // POST - Sign offer
  static String rejectOffer(int offerId) =>
      "$offerBase/$offerId/reject"; // POST - Reject offer
  static String expireOffer(int offerId) =>
      "$offerBase/$offerId/expire"; // POST - Expire offer
  static final getCandidatesReadyForOffer =
      "$adminBase/candidates/ready-for-offer";

  // GET endpoints
  static String getOffer(int offerId) =>
      "$offerBase/$offerId"; // GET - Get single offer
  static final getAllOffers = "$offerBase/"; // GET - Get all offers
  static String getOffersByStatus(String status) =>
      "$offerBase/?status=$status"; // GET - Get offers by status

  // Additional endpoints you might need
  static String getCandidateOffers(int candidateId) =>
      "$offerBase/candidate/$candidateId";

  static String getApplicationOffers(int applicationId) =>
      "$adminBase/applications/$applicationId/offers";

  static final getOfferAnalytics = "$offerBase/analytics";

  // Candidate's own offers
  static String myOffer() => "$offerBase/my-offers";

  // ==================== APPLICATION ENDPOINTS ====================

  /// GET - Get all applications (existing endpoint)
  static final getCandidateApplications = "$adminBase/applications";

  /// GET - Get all applications (alternative)
  static final getAllApplications = "$adminBase/applications/all";

  // ==================== ANALYTICS ENDPOINTS ====================
  static final getDashboardAnalytics = "$adminBase/analytics/dashboard";
  static final getUsersGrowthAnalytics = "$adminBase/analytics/users-growth";
  static final getApplicationsAnalysis =
      "$adminBase/analytics/applications-analysis";
  static final getInterviewsAnalysis =
      "$adminBase/analytics/interviews-analysis";
  static final getAssessmentsAnalysis =
      "$adminBase/analytics/assessments-analysis";
  static final getDashboardCounts = "$adminBase/dashboard-counts";
  static final getRecentActivities = "$adminBase/recent-activities";
  static final getPowerBIData = "$adminBase/powerbi/data";
  static final getPowerBIStatus = "$adminBase/powerbi/status";

  // Analytics blueprint routes
  static final getApplicationsPerRequisition =
      "$analyticsBase/analytics/applications-per-requisition";
  static final getApplicationToInterviewConversion =
      "$analyticsBase/analytics/conversion/application-to-interview";
  static final getInterviewToOfferConversion =
      "$analyticsBase/analytics/conversion/interview-to-offer";
  static final getStageDropoff = "$analyticsBase/analytics/dropoff";
  static final getTimePerStage = "$analyticsBase/analytics/time-per-stage";
  static final getMonthlyApplications =
      "$analyticsBase/analytics/applications/monthly";
  static final getCVScreeningDrop =
      "$analyticsBase/analytics/cv-screening-drop";
  static final getAssessmentPassRate =
      "$analyticsBase/analytics/assessments/pass-rate";
  static final getInterviewScheduling =
      "$analyticsBase/analytics/interviews/scheduled";
  static final getOffersByCategory =
      "$analyticsBase/analytics/offers-by-category";
  static final getAvgCVScore =
      "$analyticsBase/analytics/candidate/avg-cv-score";
  static final getAvgAssessmentScore =
      "$analyticsBase/analytics/candidate/avg-assessment-score";
  static final getSkillsFrequency =
      "$analyticsBase/analytics/candidate/skills-frequency";
  static final getExperienceDistribution =
      "$analyticsBase/analytics/candidate/experience-distribution";

  // ==================== CANDIDATE ENDPOINTS ====================
  static final getCandidateProfile = "$candidateBase/profile";
  static final updateCandidateProfile = "$candidateBase/profile";
  static final uploadCandidateDocument = "$candidateBase/upload_document";
  static final uploadProfilePicture = "$candidateBase/upload_profile_picture";
  static final getCandidateSettings = "$candidateBase/settings";
  static final updateCandidateSettings = "$candidateBase/settings";
  static final changeCandidatePassword =
      "$candidateBase/settings/change_password";
  static final updateNotificationPreferences =
      "$candidateBase/settings/notifications";
  static final deactivateCandidateAccount =
      "$candidateBase/settings/deactivate";
  static final getCandidateNotifications = "$candidateBase/notifications";

  // ==================== HELPER METHODS ====================

  /// Helper method to get all endpoints for a specific interview
  static Map<String, String> getInterviewEndpoints(int interviewId) {
    return {
      'updateStatus': updateInterviewStatus(interviewId),
      'feedback': submitInterviewFeedback(interviewId),
      'getFeedback': getInterviewFeedback(interviewId),
      'reschedule': rescheduleInterview(interviewId),
      'cancel': cancelSingleInterview(interviewId),
      'reminders': getInterviewReminders(interviewId),
      'notes': getInterviewNotes(interviewId),
      'addNotes': addInterviewNotes(interviewId),
      'calendarSync': syncSingleInterviewCalendar(interviewId),
      'calendarStatus': getInterviewCalendarStatus(interviewId),
      'feedbackSummary': getFeedbackSummary(interviewId),
      'workflowNext': moveInterviewToNextStage(interviewId),
      'workflowPrevious': moveInterviewToPreviousStage(interviewId),
      'requestFeedback': requestFeedback(interviewId),
      'sendImmediateReminder': sendImmediateReminder(interviewId),
    };
  }

  /// Helper method to get dashboard endpoints
  static Map<String, String> getDashboardEndpoints() {
    return {
      'today': getTodaysInterviews,
      'upcoming': getUpcomingInterviews,
      'past': getPastInterviews,
      'actionRequired': getInterviewsRequiringAction,
      'analytics': getInterviewAnalytics,
      'noShowAnalytics': getNoShowAnalytics,
      'feedbackAnalytics': getFeedbackAnalytics,
      'interviewerAnalytics': getInterviewerAnalytics,
      'pipelineStats': getPipelineStats,
      'quickStats': getPipelineQuickStats,
      'stagesCount': getPipelineStagesCount,
    };
  }

  /// Helper method to get bulk operation endpoints
  static Map<String, String> getBulkOperationEndpoints() {
    return {
      'bulkStatus': bulkUpdateInterviewStatus,
      'bulkReminders': bulkScheduleReminders,
      'bulkFeedbackRequest': bulkRequestFeedback,
      'bulkCalendarSync': bulkSyncInterviewCalendar,
    };
  }

  /// Helper method to get recruitment pipeline endpoints
  static Map<String, String> getRecruitmentPipelineEndpoints() {
    return {
      'pipelineStats': getPipelineStats,
      'quickStats': getPipelineQuickStats,
      'stagesCount': getPipelineStagesCount,
      'filteredApplications': getFilteredApplications,
      'jobsWithStats': getJobsWithStats,
      'todayInterviews': getTodaysInterviews,
      'upcomingInterviews': getUpcomingInterviews,
      'pastInterviews': getPastInterviews,
      'allOffers': getAllOffers,
      'candidatesReadyForOffer': getCandidatesReadyForOffer,
      'analytics': getDashboardAnalytics,
      'offerAnalytics': getOfferAnalytics,
      'searchAll': searchAll(''), // Base URL without query
    };
  }

  /// Helper method to get endpoints for a specific application
  static Map<String, String> getApplicationEndpoints(int applicationId) {
    return {
      'get': getApplicationById(applicationId),
      'updateStatus': updateApplicationStatus(applicationId),
      'downloadCV': "$adminBase/applications/$applicationId/download-cv",
      'getOffers': getApplicationOffers(applicationId),
      'getAssessment': "$candidateBase/applications/$applicationId/assessment",
      'submitAssessment':
          "$candidateBase/applications/$applicationId/assessment",
      'saveDraft': "$candidateBase/applications/$applicationId/draft",
      'submitDraft': "$candidateBase/applications/submit_draft/$applicationId",
    };
  }

  /// Helper method to get endpoints for a specific job/requisition
  static Map<String, String> getJobEndpoints(int jobId) {
    return {
      'get': getJobById(jobId),
      'update': updateJob(jobId),
      'delete': deleteJob(jobId),
      'shortlist': shortlistCandidates(jobId),
      'applications': getApplicationsByJob(jobId),
      'scheduleInterview': scheduleInterview,
    };
  }

  /// Helper method to get candidate management endpoints
  static Map<String, String> getCandidateManagementEndpoints(int candidateId) {
    return {
      'getProfile': "$adminBase/candidates/$candidateId",
      'getInterviews': getCandidateInterviews(candidateId),
      'getAvailability': getCandidateAvailability(candidateId),
      'setAvailability': setCandidateAvailability(candidateId),
      'getOffers': getCandidateOffers(candidateId),
      'chat': getCandidateChat(candidateId),
    };
  }
}
