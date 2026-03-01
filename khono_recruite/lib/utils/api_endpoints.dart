import 'app_config.dart';

class ApiEndpoints {
  // ------------------- Base URLs (use AppConfig so deployed app hits Render API) -------------------
  static String get authBase => "${AppConfig.apiBase}/api/auth";
  static String get candidateBase => "${AppConfig.apiBase}/api/candidate";
  static String get adminBase => "${AppConfig.apiBase}/api/admin";
  static String get chatbotBase => "${AppConfig.apiBase}/api/chatbot";
  static String get hmBase => "${AppConfig.apiBase}/api/admin";
  static String get chatBase => "${AppConfig.apiBase}/api/chat";
  static String get analyticsBase => "${AppConfig.apiBase}/api/analytics";
  static String get aiBase => "${AppConfig.apiBase}/api/ai";
  static String get generateJobDetails => "$aiBase/generate_job_details";
  static String get generateQuestions => "$aiBase/generate_questions";

  // NEW: Offer management base URL (matches your Flask blueprint)
  static String get offerBase => "${AppConfig.apiBase}/api/offer";

  // WebSocket URL (ws for local, wss for production)
  static String get webSocketUrl => AppConfig.apiBase
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');

  // ------------------- Auth -------------------
  static String get register => "$authBase/register";
  static String get verify => "$authBase/verify";
  static String get resendVerification => "$authBase/resend-verification";
  static String get login => "$authBase/login";
  static String get logout => "$authBase/logout";
  static String get forgotPassword => "$authBase/forgot-password";
  static String get resetPassword => "$authBase/reset-password";
  static String get changePassword => "$authBase/change-password";
  static String get currentUser => "$authBase/me";
  static String get updateAuthProfile => "$authBase/profile";
  static String get refresh => "$authBase/refresh";
  static String get adminEnroll => "$authBase/admin-enroll";
  static String get firebaseLogin => "$authBase/firebase-login";

  // ------------------- OAuth (UPDATED FOR SUPABASE) -------------------
  static String get googleOAuth => "$authBase/google";
  static String get githubOAuth => "$authBase/github";
  static String get supabaseCallback =>
      "$authBase/callback"; // New unified callback

  // ------------------- SSO -------------------
  static String get ssoLogout => "$authBase/sso/logout"; // <-- ADDED

  // ------------------- MFA (UPDATED TO MATCH BACKEND) -------------------
  static String get enableMfa =>
      "$authBase/mfa/enable"; // POST - Initiate MFA setup
  static String get verifyMfaSetup =>
      "$authBase/mfa/verify"; // POST - Verify MFA setup
  static String get mfaLogin =>
      "$authBase/mfa/login"; // POST - Verify MFA during login
  static String get disableMfa => "$authBase/mfa/disable"; // POST - Disable MFA
  static String get mfaStatus => "$authBase/mfa/status"; // GET - Get MFA status
  static String get backupCodes =>
      "$authBase/mfa/backup-codes"; // GET - Get backup codes
  static String get regenerateBackupCodes =>
      "$authBase/mfa/regenerate-backup-codes"; // POST - Regenerate backup codes
  static String get parserCV => "$authBase/cv/parse"; // POST Multipart

  // ------------------- Public (no auth) -------------------
  static String get publicBase => "${AppConfig.publicApiBase}/api/public";
  static String get getPublicJobs => "$publicBase/jobs";

  // ------------------- Candidate -------------------
  static String get enrollment => "$candidateBase/enrollment";
  static String get applyJob => "$candidateBase/apply";
  static String get submitAssessment => "$candidateBase/applications";
  static String get uploadResume => "$candidateBase/upload_resume";
  static String get getApplications => "$candidateBase/applications";
  static String get getAvailableJobs => "$candidateBase/jobs";
  static String get saveDraft => "$candidateBase/apply/save_draft";
  static String get getDrafts => "$candidateBase/applications/drafts";
  static String get submitDraft => "$candidateBase/applications/submit_draft";

  // ==================== RECRUITMENT PIPELINE ENDPOINTS ====================

  // ------------------- Pipeline Statistics -------------------
  static String get getPipelineStats => "$adminBase/pipeline/stats";
  static String get getPipelineQuickStats => "$adminBase/pipeline/quick-stats";
  static String get getPipelineStagesCount =>
      "$adminBase/pipeline/stages/count";

  // ------------------- Applications with Filters -------------------
  static String get getFilteredApplications =>
      "$adminBase/applications/filtered";

  // Enhanced existing endpoints with query params
  static String getApplicationsByStatus(String status) =>
      "$adminBase/applications/filtered?status=$status";

  static String getApplicationsByJob(int jobId) =>
      "$adminBase/applications/filtered?job_id=$jobId";

  static String searchApplications(String query) =>
      "$adminBase/applications/filtered?search=$query";

  // ------------------- Jobs with Statistics -------------------
  static String get getJobsWithStats => "$adminBase/jobs/with-stats";

  // ------------------- Interviews by Timeframe -------------------
  static String getInterviewsByTimeframe(String timeframe) =>
      "$adminBase/interviews/dashboard/$timeframe"; // today, upcoming, past, week, month

  // Alias for compatibility
  static String get getTodaysInterviews =>
      "$adminBase/interviews/dashboard/today";
  static String get getUpcomingInterviews =>
      "$adminBase/interviews/dashboard/upcoming";
  static String get getPastInterviews => "$adminBase/interviews/dashboard/past";
  static String get getInterviewsForCalendar => "$adminBase/interviews/calendar";

  // ------------------- Update Application Status -------------------
  static String updateApplicationStatus(int applicationId) =>
      "$adminBase/applications/$applicationId/status";

  // ------------------- Global Search -------------------
  static String searchAll(String query) => "$adminBase/search?q=$query";

  // ------------------- Admin / Hiring Manager -------------------
  static String get adminJobs => "$adminBase/jobs";
  static String getJobById(int id) => "$adminBase/jobs/$id";
  static String get createJob => "$adminBase/jobs";
  static String updateJob(int id) => "$adminBase/jobs/$id";
  static String deleteJob(int id) => "$adminBase/jobs/$id";

  // Add these if not already present
  static String getJobDetailed(int id) => "$adminBase/jobs/$id/detailed";
  static String restoreJob(int id) => "$adminBase/jobs/$id/restore";
  static String getJobActivity(int id) => "$adminBase/jobs/$id/activity";
  static String getJobApplications(int id) =>
      "$adminBase/jobs/$id/applications";
  static String get getJobStats => "$adminBase/jobs/stats";
  static String get viewCandidates => "$adminBase/candidates";
  static String getApplicationById(int id) => "$adminBase/applications/$id";
  static String getCandidateApplicationsByCandidateId(int candidateId) =>
      "$adminBase/candidates/$candidateId/applications";
  static String shortlistCandidates(int jobId) =>
      "$adminBase/jobs/$jobId/shortlist";
  static String get scheduleInterview => "$adminBase/interviews";
  static String get getAllInterviews => "$adminBase/interviews";
  static String cancelInterview(int interviewId) =>
      "$adminBase/interviews/cancel/$interviewId";
  static String get getNotifications => "$adminBase/notifications";
  static String markNotificationRead(int notificationId) =>
      "$adminBase/notifications/$notificationId/read";
  static String get auditLogs => "$adminBase/audits";
  static String get parseResume => "$adminBase/cv/parse";
  static String get cvReviews => "$adminBase/cv-reviews";
  static String get allCVs => "$adminBase/cv-reviews";
  static String get getUsers => "$adminBase/users";

  // ------------------- Test Packs -------------------
  static String get getTestPacks => "$adminBase/test-packs";
  static String getTestPackById(int id) => "$adminBase/test-packs/$id";
  static String get createTestPack => "$adminBase/test-packs";
  static String updateTestPack(int id) => "$adminBase/test-packs/$id";
  static String deleteTestPack(int id) => "$adminBase/test-packs/$id";

  // ==================== INTERVIEW LIFECYCLE ENHANCEMENTS ====================

  // ------------------- Interview Status Updates -------------------
  /// PATCH ΓÇô Update interview status (completed, no_show, cancelled_by_candidate, etc.)
  /// PATCH ΓÇô Update interview status (completed, no_show, cancelled_by_candidate, etc.)
  static String updateInterviewStatus(int interviewId) =>
      "$adminBase/interviews/$interviewId/status";

  /// GET ΓÇô Get all interviews for a candidate (existing)
  /// GET ΓÇô Get all interviews for a candidate (existing)
  static String getCandidateInterviews(int candidateId) =>
      "$adminBase/interviews?candidate_id=$candidateId";

  /// PUT/PATCH ΓÇô Reschedule an interview
  /// PUT/PATCH ΓÇô Reschedule an interview
  static String rescheduleInterview(int interviewId) =>
      "$adminBase/interviews/reschedule/$interviewId";

  /// DELETE ΓÇô Cancel an interview
  /// DELETE ΓÇô Cancel an interview
  static String cancelSingleInterview(int interviewId) =>
      "$adminBase/interviews/cancel/$interviewId";

  // ------------------- Interview Feedback -------------------
  /// POST ΓÇô Submit interview feedback
  /// POST ΓÇô Submit interview feedback
  static String submitInterviewFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback";

  /// GET ΓÇô Get all feedback for an interview
  /// GET ΓÇô Get all feedback for an interview
  static String getInterviewFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback";

  /// POST ΓÇô Request feedback from interviewer (email trigger)
  /// POST ΓÇô Request feedback from interviewer (email trigger)
  static String requestFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback/request";

  /// GET ΓÇô Get feedback summary for an interview
  /// GET ΓÇô Get feedback summary for an interview
  static String getFeedbackSummary(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback/summary";

  // ------------------- Interview Reminders -------------------
  /// POST ΓÇô Schedule automated reminders for interviews
  static String get scheduleInterviewReminders =>
      "$adminBase/interviews/reminders/schedule";

  /// GET ΓÇô Get all reminders for an interview
  /// GET ΓÇô Get all reminders for an interview
  static String getInterviewReminders(int interviewId) =>
      "$adminBase/interviews/$interviewId/reminders";

  /// POST ΓÇô Send immediate reminder (ad-hoc)
  /// POST ΓÇô Send immediate reminder (ad-hoc)
  static String sendImmediateReminder(int interviewId) =>
      "$adminBase/interviews/$interviewId/reminders/send";

  /// DELETE ΓÇô Cancel a scheduled reminder
  /// DELETE ΓÇô Cancel a scheduled reminder
  static String cancelInterviewReminder(int reminderId) =>
      "$adminBase/interviews/reminders/$reminderId";

  // ------------------- Interview Analytics -------------------
  /// GET ΓÇô Get interview statistics and metrics
  static String get getInterviewAnalytics => "$adminBase/interviews/analytics";

  /// GET ΓÇô Get no-show statistics
  static String get getNoShowAnalytics =>
      "$adminBase/interviews/analytics/no-shows";

  /// GET ΓÇô Get feedback completion rates
  static String get getFeedbackAnalytics =>
      "$adminBase/interviews/analytics/feedback";

  /// GET ΓÇô Get interviewer performance metrics
  static String get getInterviewerAnalytics =>
      "$adminBase/interviews/analytics/interviewers";

  // ------------------- Interview Notes -------------------
  /// POST ΓÇô Add notes to an interview
  /// POST ΓÇô Add notes to an interview
  static String addInterviewNotes(int interviewId) =>
      "$adminBase/interviews/$interviewId/notes";

  /// GET ΓÇô Get all notes for an interview
  /// GET ΓÇô Get all notes for an interview
  static String getInterviewNotes(int interviewId) =>
      "$adminBase/interviews/$interviewId/notes";

  /// PUT ΓÇô Update interview notes
  /// PUT ΓÇô Update interview notes
  static String updateInterviewNotes(int noteId) =>
      "$adminBase/interviews/notes/$noteId";

  /// DELETE ΓÇô Delete interview notes
  /// DELETE ΓÇô Delete interview notes
  static String deleteInterviewNotes(int noteId) =>
      "$adminBase/interviews/notes/$noteId";

  // ------------------- Interview Workflow -------------------
  /// POST ΓÇô Move interview to next stage
  /// POST ΓÇô Move interview to next stage
  static String moveInterviewToNextStage(int interviewId) =>
      "$adminBase/interviews/$interviewId/workflow/next";

  /// POST ΓÇô Move interview to previous stage
  /// POST ΓÇô Move interview to previous stage
  static String moveInterviewToPreviousStage(int interviewId) =>
      "$adminBase/interviews/$interviewId/workflow/previous";

  /// GET ΓÇô Get interview workflow stages
  static String get getInterviewWorkflowStages =>
      "$adminBase/interviews/workflow/stages";

  // ------------------- Bulk Interview Operations -------------------
  /// POST ΓÇô Bulk update interview statuses
  static String get bulkUpdateInterviewStatus =>
      "$adminBase/interviews/bulk/status";

  /// POST ΓÇô Bulk schedule reminders
  static String get bulkScheduleReminders =>
      "$adminBase/interviews/bulk/reminders";

  /// POST ΓÇô Bulk request feedback
  static String get bulkRequestFeedback =>
      "$adminBase/interviews/bulk/feedback/request";

  // ------------------- Interview Templates -------------------
  /// GET ΓÇô Get all interview templates
  static String get getInterviewTemplates => "$adminBase/interviews/templates";

  /// GET ΓÇô Get specific interview template
  /// GET ΓÇô Get specific interview template
  static String getInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  /// POST ΓÇô Create new interview template
  static String get createInterviewTemplate =>
      "$adminBase/interviews/templates";

  /// PUT ΓÇô Update interview template
  /// PUT ΓÇô Update interview template
  static String updateInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  /// DELETE ΓÇô Delete interview template
  /// DELETE ΓÇô Delete interview template
  static String deleteInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  // ------------------- Candidate Availability -------------------
  /// GET ΓÇô Get candidate availability
  /// GET ΓÇô Get candidate availability
  static String getCandidateAvailability(int candidateId) =>
      "$adminBase/candidates/$candidateId/availability";

  /// POST ΓÇô Set candidate availability
  /// POST ΓÇô Set candidate availability
  static String setCandidateAvailability(int candidateId) =>
      "$adminBase/candidates/$candidateId/availability";

  /// POST ΓÇô Check interview scheduling conflicts
  static String get checkSchedulingConflicts =>
      "$adminBase/interviews/conflict-check";

  // ------------------- Interview Dashboard -------------------
  /// GET ΓÇô Get interviews requiring action
  static String get getInterviewsRequiringAction =>
      "$adminBase/interviews/dashboard/action-required";

  // ------------------- Shared Notes & Meetings -------------------
  static String get createNote => "$adminBase/shared-notes";
  static String get getNotes => "$adminBase/shared-notes";
  static String getNoteById(int id) => "$adminBase/shared-notes/$id";
  static String updateNote(int id) => "$adminBase/shared-notes/$id";
  static String deleteNote(int id) => "$adminBase/shared-notes/$id";

  static String get createMeeting => "$adminBase/meetings";
  static String get getMeetings => "$adminBase/meetings";
  static String getMeetingById(int id) => "$adminBase/meetings/$id";
  static String updateMeeting(int id) => "$adminBase/meetings/$id";
  static String deleteMeeting(int id) => "$adminBase/meetings/$id";
  static String cancelMeeting(int id) => "$adminBase/meetings/$id/cancel";
  static String get getUpcomingMeetings => "$adminBase/meetings/upcoming";

  // ------------------- Interview Calendar (Google Calendar) -------------------
  /// GET ΓÇô Sync & compare upcoming interviews with Google Calendar
  static String get syncInterviewCalendar =>
      "$adminBase/interviews/calendar/sync";

  /// POST ΓÇô Sync a single interview to Google Calendar
  /// POST ΓÇô Sync a single interview to Google Calendar
  static String syncSingleInterviewCalendar(int interviewId) =>
      "$adminBase/interviews/$interviewId/calendar/sync";

  /// POST ΓÇô Bulk sync multiple interviews
  static String get bulkSyncInterviewCalendar =>
      "$adminBase/interviews/calendar/bulk-sync";

  /// GET ΓÇô Get calendar status for a specific interview
  /// GET ΓÇô Get calendar status for a specific interview
  static String getInterviewCalendarStatus(int interviewId) =>
      "$adminBase/interviews/$interviewId/calendar/status";

  // ------------------- AI Chatbot -------------------
  static String get parseCV => "$chatbotBase/parse_cv";
  static String get askBot => "$chatbotBase/ask";

  // ==================== CHAT FEATURE ENDPOINTS ====================

  // Thread Management
  static String get getChatThreads => "$chatBase/threads";
  static String get createChatThread => "$chatBase/threads";
  static String getChatThread(int id) => "$chatBase/threads/$id";

  // Messages
  static String getChatMessages(int threadId) =>
      "$chatBase/threads/$threadId/messages";
  static String sendChatMessage(int threadId) =>
      "$chatBase/threads/$threadId/messages";
  static String markMessagesAsRead(int threadId) =>
      "$chatBase/threads/$threadId/mark-read";

  // Search
  static String get searchChatMessages => "$chatBase/search";

  // Presence
  static String get updatePresence => "$chatBase/presence";

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
  static String get draftOffer => "$offerBase/"; // POST - Draft offer
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
  static String get getCandidatesReadyForOffer =>
      "$adminBase/candidates/ready-for-offer";

  // GET endpoints
  static String getOffer(int offerId) =>
      "$offerBase/$offerId"; // GET - Get single offer
  static String get getAllOffers => "$offerBase/"; // GET - Get all offers
  static String getOffersByStatus(String status) =>
      "$offerBase/?status=$status"; // GET - Get offers by status

  // Additional endpoints you might need
  static String getCandidateOffers(int candidateId) =>
      "$offerBase/candidate/$candidateId";

  static String getApplicationOffers(int applicationId) =>
      "$adminBase/applications/$applicationId/offers";

  static String get getOfferAnalytics => "$offerBase/analytics";

  // Candidate's own offers
  static String myOffer() => "$offerBase/my-offers";

  // ==================== APPLICATION ENDPOINTS ====================

  /// GET - Get all applications (existing endpoint)
  static String get getCandidateApplications => "$adminBase/applications";

  /// GET - Get all applications (alternative)
  static String get getAllApplications => "$adminBase/applications/all";

  // ==================== ANALYTICS ENDPOINTS ====================
  static String get getDashboardAnalytics => "$adminBase/analytics/dashboard";
  static String get getUsersGrowthAnalytics =>
      "$adminBase/analytics/users-growth";
  static String get getApplicationsAnalysis =>
      "$adminBase/analytics/applications-analysis";
  static String get getInterviewsAnalysis =>
      "$adminBase/analytics/interviews-analysis";
  static String get getAssessmentsAnalysis =>
      "$adminBase/analytics/assessments-analysis";
  static String get getDashboardCounts => "$adminBase/dashboard-counts";
  static String get getRecentActivities => "$adminBase/recent-activities";
  static String get getPowerBIData => "$adminBase/powerbi/data";
  static String get getPowerBIStatus => "$adminBase/powerbi/status";

  // Analytics blueprint routes (prefix /api, routes under /analytics/...)
  static String get getApplicationsPerRequisition =>
      "$analyticsBase/applications-per-requisition";
  static String get getApplicationToInterviewConversion =>
      "$analyticsBase/conversion/application-to-interview";
  static String get getInterviewToOfferConversion =>
      "$analyticsBase/conversion/interview-to-offer";
  static String get getStageDropoff => "$analyticsBase/dropoff";
  static String get getTimePerStage => "$analyticsBase/time-per-stage";
  static String get getMonthlyApplications =>
      "$analyticsBase/applications/monthly";
  static String get getCVScreeningDrop => "$analyticsBase/cv-screening-drop";
  static String get getAssessmentPassRate =>
      "$analyticsBase/assessments/pass-rate";
  static String get getInterviewScheduling =>
      "$analyticsBase/interviews/scheduled";
  static String get getOffersByCategory => "$analyticsBase/offers-by-category";
  static String get getAvgCVScore =>
      "$analyticsBase/candidate/avg-cv-score";
  static String get getAvgAssessmentScore =>
      "$analyticsBase/candidate/avg-assessment-score";
  static String get getSkillsFrequency =>
      "$analyticsBase/candidate/skills-frequency";
  static String get getExperienceDistribution =>
      "$analyticsBase/candidate/experience-distribution";
  static String get getGenderDistribution =>
      "$analyticsBase/candidate/gender-distribution";
  static String get getEthnicityDistribution =>
      "$analyticsBase/candidate/ethnicity-distribution";

  // ==================== CANDIDATE ENDPOINTS ====================
  static String get getCandidateProfile => "$candidateBase/profile";
  static String get updateCandidateProfile => "$candidateBase/profile";
  static String get uploadCandidateDocument => "$candidateBase/upload_document";
  static String get uploadProfilePicture =>
      "$candidateBase/upload_profile_picture";
  static String get getCandidateSettings => "$candidateBase/settings";
  static String get updateCandidateSettings => "$candidateBase/settings";
  static String get changeCandidatePassword =>
      "$candidateBase/settings/change_password";
  static String get updateNotificationPreferences =>
      "$candidateBase/settings/notifications";
  static String get deactivateCandidateAccount =>
      "$candidateBase/settings/deactivate";
  static String get getCandidateNotifications => "$candidateBase/notifications";

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
