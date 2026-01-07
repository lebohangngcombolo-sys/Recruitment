class ApiEndpoints {
  // ------------------- Base URLs -------------------
  static const authBase = "http://127.0.0.1:5000/api/auth";
  static const candidateBase = "http://127.0.0.1:5000/api/candidate";
  static const adminBase = "http://127.0.0.1:5000/api/admin";
  static const chatbotBase = "http://127.0.0.1:5000/api/chatbot";
  static const hmBase = "http://127.0.0.1:5000/api/admin";
  static const chatBase = "http://127.0.0.1:5000/api/chat";
  static const analyticsBase = "http://127.0.0.1:5000/api/analytics";

  // NEW: Offer management base URL (matches your Flask blueprint)
  static const offerBase = "http://127.0.0.1:5000/api/offer";

  // WebSocket URL (for real-time chat)
  static const webSocketUrl =
      "ws://127.0.0.1:5000"; // Use wss:// for production with SSL

  // ------------------- Auth -------------------
  static const register = "$authBase/register";
  static const verify = "$authBase/verify";
  static const login = "$authBase/login";
  static const logout = "$authBase/logout";
  static const forgotPassword = "$authBase/forgot-password";
  static const resetPassword = "$authBase/reset-password";
  static const changePassword = "$authBase/change-password";
  static const currentUser = "$authBase/me";
  static const adminEnroll = "$authBase/admin-enroll";
  static const firebaseLogin = "$authBase/firebase-login";

  // ------------------- OAuth (UPDATED FOR SUPABASE) -------------------
  static const googleOAuth = "$authBase/google";
  static const githubOAuth = "$authBase/github";
  static const supabaseCallback = "$authBase/callback"; // New unified callback

  // ------------------- SSO -------------------
  static const ssoLogout = "$authBase/sso/logout"; // <-- ADDED

  // ------------------- MFA (UPDATED TO MATCH BACKEND) -------------------
  static const enableMfa = "$authBase/mfa/enable"; // POST - Initiate MFA setup
  static const verifyMfaSetup =
      "$authBase/mfa/verify"; // POST - Verify MFA setup
  static const mfaLogin =
      "$authBase/mfa/login"; // POST - Verify MFA during login
  static const disableMfa = "$authBase/mfa/disable"; // POST - Disable MFA
  static const mfaStatus = "$authBase/mfa/status"; // GET - Get MFA status
  static const backupCodes =
      "$authBase/mfa/backup-codes"; // GET - Get backup codes
  static const regenerateBackupCodes =
      "$authBase/mfa/regenerate-backup-codes"; // POST - Regenerate backup codes
  static const String parserCV = "$authBase/cv/parse"; // POST Multipart

  // ------------------- Candidate -------------------
  static const enrollment = "$candidateBase/enrollment";
  static const applyJob = "$candidateBase/apply";
  static const submitAssessment = "$candidateBase/applications";
  static const uploadResume = "$candidateBase/upload_resume";
  static const getApplications = "$candidateBase/applications";
  static const getAvailableJobs = "$candidateBase/jobs";
  static const saveDraft = "$candidateBase/apply/save_draft";
  static const getDrafts = "$candidateBase/applications/drafts";
  static const submitDraft = "$candidateBase/applications/submit_draft";

  // ==================== RECRUITMENT PIPELINE ENDPOINTS ====================

  // ------------------- Pipeline Statistics -------------------
  static const getPipelineStats = "$adminBase/pipeline/stats";
  static const getPipelineQuickStats = "$adminBase/pipeline/quick-stats";
  static const getPipelineStagesCount = "$adminBase/pipeline/stages/count";

  // ------------------- Applications with Filters -------------------
  static const getFilteredApplications = "$adminBase/applications/filtered";

  // Enhanced existing endpoints with query params
  static String getApplicationsByStatus(String status) =>
      "$adminBase/applications/filtered?status=$status";

  static String getApplicationsByJob(int jobId) =>
      "$adminBase/applications/filtered?job_id=$jobId";

  static String searchApplications(String query) =>
      "$adminBase/applications/filtered?search=$query";

  // ------------------- Jobs with Statistics -------------------
  static const getJobsWithStats = "$adminBase/jobs/with-stats";

  // ------------------- Interviews by Timeframe -------------------
  static String getInterviewsByTimeframe(String timeframe) =>
      "$adminBase/interviews/dashboard/$timeframe"; // today, upcoming, past, week, month

  // Alias for compatibility
  static const getTodaysInterviews = "$adminBase/interviews/dashboard/today";
  static const getUpcomingInterviews =
      "$adminBase/interviews/dashboard/upcoming";
  static const getPastInterviews = "$adminBase/interviews/dashboard/past";

  // ------------------- Update Application Status -------------------
  static String updateApplicationStatus(int applicationId) =>
      "$adminBase/applications/$applicationId/status";

  // ------------------- Global Search -------------------
  static String searchAll(String query) => "$adminBase/search?q=$query";

  // ------------------- Admin / Hiring Manager -------------------
  static const adminJobs = "$adminBase/jobs";
  static String getJobById(int id) => "$adminBase/jobs/$id";
  static const createJob = "$adminBase/jobs";
  static String updateJob(int id) => "$adminBase/jobs/$id";
  static String deleteJob(int id) => "$adminBase/jobs/$id";

  // Add these if not already present
  static String getJobDetailed(int id) => "$adminBase/jobs/$id/detailed";
  static String restoreJob(int id) => "$adminBase/jobs/$id/restore";
  static String getJobActivity(int id) => "$adminBase/jobs/$id/activity";
  static String getJobApplications(int id) =>
      "$adminBase/jobs/$id/applications";
  static String getJobStats = "$adminBase/jobs/stats";
  static const viewCandidates = "$adminBase/candidates";
  static String getApplicationById(int id) => "$adminBase/applications/$id";
  static String shortlistCandidates(int jobId) =>
      "$adminBase/jobs/$jobId/shortlist";
  static const scheduleInterview = "$adminBase/interviews";
  static const getAllInterviews = "$adminBase/interviews";
  static String cancelInterview(int interviewId) =>
      "$adminBase/interviews/cancel/$interviewId";
  static const getNotifications = "$adminBase/notifications";
  static const auditLogs = "$adminBase/audits";
  static const parseResume = "$adminBase/cv/parse";
  static const cvReviews = "$adminBase/cv-reviews";
  static const getUsers = "$adminBase/users";

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
  static const scheduleInterviewReminders =
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
  static const getInterviewAnalytics = "$adminBase/interviews/analytics";

  /// GET – Get no-show statistics
  static const getNoShowAnalytics = "$adminBase/interviews/analytics/no-shows";

  /// GET – Get feedback completion rates
  static const getFeedbackAnalytics =
      "$adminBase/interviews/analytics/feedback";

  /// GET – Get interviewer performance metrics
  static const getInterviewerAnalytics =
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
  static const getInterviewWorkflowStages =
      "$adminBase/interviews/workflow/stages";

  // ------------------- Bulk Interview Operations -------------------
  /// POST – Bulk update interview statuses
  static const bulkUpdateInterviewStatus = "$adminBase/interviews/bulk/status";

  /// POST – Bulk schedule reminders
  static const bulkScheduleReminders = "$adminBase/interviews/bulk/reminders";

  /// POST – Bulk request feedback
  static const bulkRequestFeedback =
      "$adminBase/interviews/bulk/feedback/request";

  // ------------------- Interview Templates -------------------
  /// GET – Get all interview templates
  static const getInterviewTemplates = "$adminBase/interviews/templates";

  /// GET – Get specific interview template
  static String getInterviewTemplate(int templateId) =>
      "$adminBase/interviews/templates/$templateId";

  /// POST – Create new interview template
  static const createInterviewTemplate = "$adminBase/interviews/templates";

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
  static const checkSchedulingConflicts =
      "$adminBase/interviews/conflict-check";

  // ------------------- Interview Dashboard -------------------
  /// GET – Get interviews requiring action
  static const getInterviewsRequiringAction =
      "$adminBase/interviews/dashboard/action-required";

  // ------------------- Shared Notes & Meetings -------------------
  static const createNote = "$adminBase/shared-notes";
  static const getNotes = "$adminBase/shared-notes";
  static String getNoteById(int id) => "$adminBase/shared-notes/$id";
  static String updateNote(int id) => "$adminBase/shared-notes/$id";
  static String deleteNote(int id) => "$adminBase/shared-notes/$id";

  static const createMeeting = "$adminBase/meetings";
  static const getMeetings = "$adminBase/meetings";
  static String getMeetingById(int id) => "$adminBase/meetings/$id";
  static String updateMeeting(int id) => "$adminBase/meetings/$id";
  static String deleteMeeting(int id) => "$adminBase/meetings/$id";
  static String cancelMeeting(int id) => "$adminBase/meetings/$id/cancel";
  static const getUpcomingMeetings = "$adminBase/meetings/upcoming";

  // ------------------- Interview Calendar (Google Calendar) -------------------
  /// GET – Sync & compare upcoming interviews with Google Calendar
  static const syncInterviewCalendar = "$adminBase/interviews/calendar/sync";

  /// POST – Sync a single interview to Google Calendar
  static String syncSingleInterviewCalendar(int interviewId) =>
      "$adminBase/interviews/$interviewId/calendar/sync";

  /// POST – Bulk sync multiple interviews
  static const bulkSyncInterviewCalendar =
      "$adminBase/interviews/calendar/bulk-sync";

  /// GET – Get calendar status for a specific interview
  static String getInterviewCalendarStatus(int interviewId) =>
      "$adminBase/interviews/$interviewId/calendar/status";

  // ------------------- AI Chatbot -------------------
  static const parseCV = "$chatbotBase/parse_cv";
  static const askBot = "$chatbotBase/ask";

  // ==================== CHAT FEATURE ENDPOINTS ====================

  // Thread Management
  static const getChatThreads = "$chatBase/threads";
  static const createChatThread = "$chatBase/threads";
  static String getChatThread(int id) => "$chatBase/threads/$id";

  // Messages
  static String getChatMessages(int threadId) =>
      "$chatBase/threads/$threadId/messages";
  static String sendChatMessage(int threadId) =>
      "$chatBase/threads/$threadId/messages";
  static String markMessagesAsRead(int threadId) =>
      "$chatBase/threads/$threadId/mark-read";

  // Search
  static const searchChatMessages = "$chatBase/search";

  // Presence
  static const updatePresence = "$chatBase/presence";

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
  static const draftOffer = "$offerBase/"; // POST - Draft offer
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
  static const getCandidatesReadyForOffer =
      "$adminBase/candidates/ready-for-offer";

  // GET endpoints
  static String getOffer(int offerId) =>
      "$offerBase/$offerId"; // GET - Get single offer
  static const getAllOffers = "$offerBase/"; // GET - Get all offers
  static String getOffersByStatus(String status) =>
      "$offerBase/?status=$status"; // GET - Get offers by status

  // Additional endpoints you might need
  static String getCandidateOffers(int candidateId) =>
      "$offerBase/candidate/$candidateId";

  static String getApplicationOffers(int applicationId) =>
      "$adminBase/applications/$applicationId/offers";

  static const getOfferAnalytics = "$offerBase/analytics";

  // Candidate's own offers
  static String myOffer() => "$offerBase/my-offers";

  // ==================== APPLICATION ENDPOINTS ====================

  /// GET - Get all applications (existing endpoint)
  static const getCandidateApplications = "$adminBase/applications";

  /// GET - Get all applications (alternative)
  static const getAllApplications = "$adminBase/applications/all";

  // ==================== ANALYTICS ENDPOINTS ====================
  static const getDashboardAnalytics = "$adminBase/analytics/dashboard";
  static const getUsersGrowthAnalytics = "$adminBase/analytics/users-growth";
  static const getApplicationsAnalysis =
      "$adminBase/analytics/applications-analysis";
  static const getInterviewsAnalysis =
      "$adminBase/analytics/interviews-analysis";
  static const getAssessmentsAnalysis =
      "$adminBase/analytics/assessments-analysis";
  static const getDashboardCounts = "$adminBase/dashboard-counts";
  static const getRecentActivities = "$adminBase/recent-activities";
  static const getPowerBIData = "$adminBase/powerbi/data";
  static const getPowerBIStatus = "$adminBase/powerbi/status";

  // Analytics blueprint routes
  static const getApplicationsPerRequisition =
      "$analyticsBase/analytics/applications-per-requisition";
  static const getApplicationToInterviewConversion =
      "$analyticsBase/analytics/conversion/application-to-interview";
  static const getInterviewToOfferConversion =
      "$analyticsBase/analytics/conversion/interview-to-offer";
  static const getStageDropoff = "$analyticsBase/analytics/dropoff";
  static const getTimePerStage = "$analyticsBase/analytics/time-per-stage";
  static const getMonthlyApplications =
      "$analyticsBase/analytics/applications/monthly";
  static const getCVScreeningDrop =
      "$analyticsBase/analytics/cv-screening-drop";
  static const getAssessmentPassRate =
      "$analyticsBase/analytics/assessments/pass-rate";
  static const getInterviewScheduling =
      "$analyticsBase/analytics/interviews/scheduled";
  static const getOffersByCategory =
      "$analyticsBase/analytics/offers-by-category";
  static const getAvgCVScore =
      "$analyticsBase/analytics/candidate/avg-cv-score";
  static const getAvgAssessmentScore =
      "$analyticsBase/analytics/candidate/avg-assessment-score";
  static const getSkillsFrequency =
      "$analyticsBase/analytics/candidate/skills-frequency";
  static const getExperienceDistribution =
      "$analyticsBase/analytics/candidate/experience-distribution";

  // ==================== CANDIDATE ENDPOINTS ====================
  static const getCandidateProfile = "$candidateBase/profile";
  static const updateCandidateProfile = "$candidateBase/profile";
  static const uploadCandidateDocument = "$candidateBase/upload_document";
  static const uploadProfilePicture = "$candidateBase/upload_profile_picture";
  static const getCandidateSettings = "$candidateBase/settings";
  static const updateCandidateSettings = "$candidateBase/settings";
  static const changeCandidatePassword =
      "$candidateBase/settings/change_password";
  static const updateNotificationPreferences =
      "$candidateBase/settings/notifications";
  static const deactivateCandidateAccount =
      "$candidateBase/settings/deactivate";
  static const getCandidateNotifications = "$candidateBase/notifications";

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
