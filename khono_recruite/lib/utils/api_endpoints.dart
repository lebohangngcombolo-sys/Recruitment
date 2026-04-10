class ApiEndpoints {
  // ------------------- Base URLs -------------------
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:5000',
  );

  static const publicApiBase = String.fromEnvironment(
    'PUBLIC_API_BASE',
    defaultValue: apiBase,
  );

  static const authBase = "$apiBase/api/auth";
  static const candidateBase = "$apiBase/api/candidate";
  static const adminBase = "$apiBase/api/admin";
  static const hmBase =
      "$apiBase/api/admin"; // Hiring manager uses admin routes
  static const analyticsBase = "$apiBase/api/analytics";
  static const chatBase = "$apiBase/api/chat";
  static const aiBase = "$apiBase/api/ai";
  static const offerBase = "$apiBase/api/offer";
  static const publicBase = "$publicApiBase/api/public";

  // WebSocket URL (for real-time chat)
  static String get webSocketUrl {
    final wsBase = apiBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return wsBase;
  }

  // ------------------- Auth, OAuth & MFA -------------------
  static const register = "$authBase/register";
  static const verify = "$authBase/verify";
  static const resendVerification = "$authBase/resend-verification";
  static const login = "$authBase/login";
  static const logout = "$authBase/logout";
  static const forgotPassword = "$authBase/forgot-password";
  static const resetPassword = "$authBase/reset-password";
  static const changePassword = "$authBase/change-password";
  static const changeCandidatePassword =
      "$authBase/change-password"; // Alias for settings
  static const currentUser = "$authBase/me";
  static const refresh = "$authBase/refresh";
  static const adminEnroll = "$authBase/admin-enroll";
  static const firebaseLogin = "$authBase/firebase-login";
  static const updateAuthProfile = "$authBase/profile";
  static const uploadAuthProfilePicture = "$authBase/upload_profile_picture";
  static const String parserCV = "$authBase/cv/parse";

  static const googleOAuth = "$authBase/google";
  static const githubOAuth = "$authBase/github";
  static const supabaseCallback = "$authBase/callback";
  static const ssoLogout = "$authBase/sso/logout";

  static const enableMfa = "$authBase/mfa/enable";
  static const verifyMfaSetup = "$authBase/mfa/verify";
  static const mfaLogin = "$authBase/mfa/login";
  static const disableMfa = "$authBase/mfa/disable";
  static const mfaStatus = "$authBase/mfa/status";
  static const backupCodes = "$authBase/mfa/backup-codes";
  static const regenerateBackupCodes = "$authBase/mfa/regenerate-backup-codes";

  // ------------------- Public -------------------
  static const getPublicJobs = "$publicBase/jobs";

  // ------------------- Candidate -------------------
  static const enrollment = "$candidateBase/enrollment";
  static const applyJob = "$candidateBase/apply";
  static const submitAssessment = "$candidateBase/applications";
  static const uploadResume = "$candidateBase/upload_resume";
  static const getApplications = "$candidateBase/applications";
  static const getCandidateApplications = "$candidateBase/applications";
  static const getAvailableJobs = "$candidateBase/jobs";
  static const saveDraft = "$candidateBase/apply/save_draft";
  static const getDrafts = "$candidateBase/applications/drafts";
  static const submitDraft = "$candidateBase/applications/submit_draft";
  static const getCandidateInterviewsList = "$candidateBase/interviews";
  static const getCandidateNotifications = "$candidateBase/notifications";

  static String getApplicationInterviewSlots(int applicationId) =>
      "$candidateBase/applications/$applicationId/interview-slots";
  static String bookInterviewSlot(int applicationId) =>
      "$candidateBase/applications/$applicationId/book-slot";
  static String acceptInterviewInvite(int interviewId) =>
      "$candidateBase/interviews/$interviewId/accept";
  static String declineInterviewInvite(int interviewId) =>
      "$candidateBase/interviews/$interviewId/decline";
  static String markCandidateNotificationRead(int id) =>
      "$candidateBase/notifications/$id/read";

  // ------------------- Admin & Hiring Manager -------------------
  static const adminJobs = "$adminBase/jobs";
  static const teamCollaboration = "$adminBase/team-collaboration";
  static const adminUsers = "$adminBase/users";
  static const getUsers = "$adminBase/users";
  static const candidates = "$adminBase/candidates";
  static const viewCandidates = "$adminBase/candidates";
  static const auditLogs = "$adminBase/audits";
  static const getNotifications = "$adminBase/notifications";
  static const cvReviews = "$adminBase/cv-reviews";
  static const createJob = "$adminBase/jobs";

  // Job approval endpoints
  static String approveJob(int jobId) => "$adminBase/jobs/$jobId/approve";
  static String rejectJob(int jobId) => "$adminBase/jobs/$jobId/reject";
  static const getRecentActivities = "$adminBase/recent-activities";
  static const getPowerBIStatus = "$adminBase/powerbi/status";
  static const getDashboardCounts = "$adminBase/dashboard-counts";
  static const getDashboardAnalytics = "$adminBase/analytics/dashboard";
  static const getCandidatesReadyForOffer =
      "$adminBase/candidates/ready-for-offer";

  static String getJobById(int id) => "$adminBase/jobs/$id";
  static String updateJob(int id) => "$adminBase/jobs/$id";
  static String deleteJob(int id) => "$adminBase/jobs/$id";
  static String getJobDetailed(int id) => "$adminBase/jobs/$id/detailed";
  static String restoreJob(int id) => "$adminBase/jobs/$id/restore";
  static String getJobActivity(int id) => "$adminBase/jobs/$id/activity";
  static String getJobApplications(int id) =>
      "$adminBase/jobs/$id/applications";
  static String getJobStats(int id) => "$adminBase/jobs/$id/stats";

  static const bulkApproveJobs = "$adminBase/jobs/bulk-approve";
  static const bulkRejectJobs = "$adminBase/jobs/bulk-reject";
  static const getApplicationsForMyJobs =
      "$adminBase/jobs/applications/for-my-jobs";

  static String getApplicationById(int id) => "$adminBase/applications/$id";
  static String getApplicationTimeline(int applicationId) =>
      "$adminBase/applications/$applicationId/timeline";
  static String addApplicationTimelineNote(int applicationId) =>
      "$adminBase/applications/$applicationId/timeline/notes";
  static String updateApplicationStatus(int applicationId) =>
      "$adminBase/applications/$applicationId/status";
  static String updateApplicationRecommendation(int applicationId) =>
      "$adminBase/applications/$applicationId/recommendation";
  static String getCandidateApplicationsByCandidateId(int candidateId) =>
      "$adminBase/candidates/$candidateId/applications";
  static String getCandidateAvailability(int id) =>
      "$adminBase/candidates/$id/availability";
  static String setCandidateAvailability(int id) =>
      "$adminBase/candidates/$id/availability";

  // ------------------- Pipeline & Analytics -------------------
  static const getPipelineStats = "$adminBase/pipeline/stats";
  static const getPipelineQuickStats = "$adminBase/pipeline/quick-stats";
  static const getPipelineStagesCount = "$adminBase/pipeline/stages/count";
  static const getFilteredApplications = "$adminBase/applications/filtered";
  static const getJobsWithStats = "$adminBase/jobs/with-stats";
  static const getGenderDistribution =
      "$analyticsBase/candidate/gender-distribution";
  static const getEthnicityDistribution =
      "$analyticsBase/candidate/ethnicity-distribution";
  static const pipelineActivity = "$adminBase/activity/pipeline";

  // New Analytics Endpoints
  static const getApplicationsPerRequisition =
      "$analyticsBase/applications-per-requisition";
  static const getTimePerStage = "$analyticsBase/time-per-stage";
  static const getApplicationToInterviewConversion =
      "$analyticsBase/conversion/application-to-interview";
  static const getStageDropoff = "$analyticsBase/dropoff";
  static const getMonthlyApplications = "$analyticsBase/applications/monthly";
  static const getSkillsFrequency = "$analyticsBase/candidate/skills-frequency";
  static const getExperienceDistribution =
      "$analyticsBase/candidate/experience-distribution";
  static const getCVScreeningDrop = "$analyticsBase/cv-screening-drop";
  static const getAssessmentPassRate = "$analyticsBase/assessments/pass-rate";

  static String getApplicationsByStatus(String status) =>
      "$adminBase/applications/filtered?status=$status";
  static String getApplicationsByJob(int jobId) =>
      "$adminBase/applications/filtered?job_id=$jobId";
  static String searchApplications(String query) =>
      "$adminBase/applications/filtered?search=$query";

  // ------------------- Interviews & Slots -------------------
  static const scheduleInterview = "$adminBase/interviews";
  static const getAllInterviews = "$adminBase/interviews";
  static const getInterviewsAll = "$adminBase/interviews/all";
  static const getInterviewsForCalendar = "$adminBase/interviews/calendar";
  static const interviewSlots = "$adminBase/interview-slots";
  static const getInterviewSlots = "$adminBase/interview-slots";
  static const interviewSlotsAvailable = "$adminBase/interview-slots/available";
  static const getInterviewSlotsAvailable =
      "$adminBase/interview-slots/available";
  static const getInterviewsRequiringAction =
      "$adminBase/interviews/requiring-action";
  static const getInterviewWorkflowStages =
      "$adminBase/interviews/workflow/stages";
  static const bulkUpdateInterviewStatus =
      "$adminBase/interviews/bulk-update-status";
  static const checkSchedulingConflicts =
      "$adminBase/interviews/check-conflicts";

  static String rescheduleInterview(int id) =>
      "$adminBase/interviews/reschedule/$id";
  static String cancelInterview(int id) => "$adminBase/interviews/cancel/$id";
  static String cancelSingleInterview(int interviewId) =>
      "$adminBase/interviews/cancel/$interviewId";
  static String approveInterview(int interviewId) =>
      "$adminBase/interviews/$interviewId/approve";
  static String rejectInterview(int interviewId) =>
      "$adminBase/interviews/$interviewId/reject";
  static String updateInterviewStatus(int interviewId) =>
      "$adminBase/interviews/$interviewId/status";
  static String submitInterviewFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback";
  static String getCandidateInterviews(int candidateId) =>
      "$adminBase/interviews?candidate_id=$candidateId";
  static String deleteInterviewSlot(int id) => "$adminBase/interview-slots/$id";
  static String moveInterviewToNextStage(int id) =>
      "$adminBase/interviews/$id/next-stage";
  static String moveInterviewToPreviousStage(int id) =>
      "$adminBase/interviews/$id/previous-stage";

  static String getInterviewsByTimeframe(String timeframe) =>
      "$adminBase/interviews/dashboard/$timeframe";
  static const getTodaysInterviews = "$adminBase/interviews/dashboard/today";
  static const getUpcomingInterviews =
      "$adminBase/interviews/dashboard/upcoming";
  static const getPastInterviews = "$adminBase/interviews/dashboard/past";

  // ------------------- Interview Templates -------------------
  static const getInterviewTemplates = "$adminBase/interviews/templates";
  static const createInterviewTemplate = "$adminBase/interviews/templates";
  static String getInterviewTemplate(int id) =>
      "$adminBase/interviews/templates/$id";
  static String updateInterviewTemplate(int id) =>
      "$adminBase/interviews/templates/$id";
  static String deleteInterviewTemplate(int id) =>
      "$adminBase/interviews/templates/$id";

  // ------------------- CV Analyser & AI -------------------
  static const cvAnalyserUpload = "$apiBase/api/cv-analyser/upload";
  static const generateJobDetails = "$aiBase/generate_job_details";
  static const generateQuestions = "$aiBase/generate_questions";
  static const parseResume = "$adminBase/cv/parse";
  static const allCVs = "$adminBase/cvs";

  static String cvAnalyserStatus(String analysisId) =>
      "$apiBase/api/cv-analyser/analyses/$analysisId/status";
  static String cvAnalyserResult(String analysisId) =>
      "$apiBase/api/cv-analyser/analyses/$analysisId/result";

  // ------------------- Test Packs -------------------
  static const getTestPacks = "$adminBase/test-packs";
  static const createTestPack = "$adminBase/test-packs";
  static String getTestPackById(int id) => "$adminBase/test-packs/$id";
  static String updateTestPack(int id) => "$adminBase/test-packs/$id";
  static String deleteTestPack(int id) => "$adminBase/test-packs/$id";

  // ------------------- Shared Notes -------------------
  static const createNote = "$adminBase/shared-notes";
  static const getNotes = "$adminBase/shared-notes";
  static const getNoteById =
      "$adminBase/shared-notes"; // Used as base: $getNoteById/$id
  static const updateNote =
      "$adminBase/shared-notes"; // Used as base: $updateNote/$id
  static const deleteNote =
      "$adminBase/shared-notes"; // Used as base: $deleteNote/$id

  // ------------------- Meetings -------------------
  static const createMeeting = "$adminBase/meetings";
  static const getMeetings = "$adminBase/meetings";
  static const getMeetingById =
      "$adminBase/meetings"; // Used as base: $getMeetingById/$id
  static const updateMeeting =
      "$adminBase/meetings"; // Used as base: $updateMeeting/$id
  static const cancelMeeting =
      "$adminBase/meetings/cancel"; // Used as base: $cancelMeeting/$id
  static const deleteMeeting =
      "$adminBase/meetings"; // Used as base: $deleteMeeting/$id
  static const getUpcomingMeetings = "$adminBase/meetings/upcoming";

  // ------------------- Notification Preferences -------------------
  static const getNotificationPreferences =
      "$adminBase/notifications/preferences";
  static const updateNotificationPreferences =
      "$adminBase/notifications/preferences";

  // ------------------- Chat -------------------
  static const getChatThreads = "$chatBase/threads";
  static const createChatThread = "$chatBase/threads";
  static String getChatThread(int id) => "$chatBase/threads/$id";
  static String getChatMessages(int id) => "$chatBase/threads/$id/messages";
  static String sendChatMessage(int id) => "$chatBase/threads/$id/messages";
  static String markMessagesAsRead(int id) => "$chatBase/threads/$id/read";
  static const searchChatMessages = "$chatBase/search";
  static const updatePresence = "$chatBase/presence";
  static String getEntityChat(String type, String id) =>
      "$chatBase/entity/$type/$id";

  // ------------------- Calendar Sync -------------------
  static const syncInterviewCalendar = "$adminBase/interviews/sync-calendar";
  static String syncSingleInterviewCalendar(int id) =>
      "$adminBase/interviews/$id/sync-calendar";
  static const bulkSyncInterviewCalendar =
      "$adminBase/interviews/bulk-sync-calendar";
  static String getInterviewCalendarStatus(int id) =>
      "$adminBase/interviews/$id/calendar-status";

  // ------------------- Interview Feedback & Reminders -------------------
  static String getInterviewFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback";
  static String requestFeedback(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback/request";
  static String getFeedbackSummary(int interviewId) =>
      "$adminBase/interviews/$interviewId/feedback/summary";

  static const scheduleInterviewReminders =
      "$adminBase/interviews/reminders/schedule";
  static const bulkScheduleReminders =
      "$adminBase/interviews/bulk-schedule-reminders";
  static const bulkRequestFeedback =
      "$adminBase/interviews/bulk-request-feedback";

  static String getInterviewReminders(int interviewId) =>
      "$adminBase/interviews/$interviewId/reminders";
  static String sendImmediateReminder(int interviewId) =>
      "$adminBase/interviews/$interviewId/reminders/send-now";
  static String cancelInterviewReminder(int reminderId) =>
      "$adminBase/interviews/reminders/$reminderId";

  // ------------------- Interview Analytics -------------------
  static const getInterviewAnalytics = "$adminBase/interviews/analytics";
  static const getNoShowAnalytics = "$adminBase/interviews/analytics/no-shows";
  static const getFeedbackAnalytics =
      "$adminBase/interviews/analytics/feedback";
  static const getInterviewerAnalytics =
      "$adminBase/interviews/analytics/interviewers";

  // ------------------- Interview Notes -------------------
  static String addInterviewNotes(int interviewId) =>
      "$adminBase/interviews/$interviewId/notes";
  static String getInterviewNotes(int interviewId) =>
      "$adminBase/interviews/$interviewId/notes";
  static String updateInterviewNotes(int noteId) =>
      "$adminBase/interviews/notes/$noteId";
  static String deleteInterviewNotes(int noteId) =>
      "$adminBase/interviews/notes/$noteId";

  // ------------------- Offer Management -------------------
  static const getAllOffers = offerBase;
  static const draftOffer = "$offerBase/";
  static const getOfferAnalytics = "$offerBase/analytics";
  static const myOffers = "$offerBase/my-offers";

  static String getOffersByStatus(String status) => "$offerBase?status=$status";
  static String getOffer(int id) => "$offerBase/$id";
  static String reviewOffer(int id) => "$offerBase/$id/review";
  static String approveOffer(int id) => "$offerBase/$id/approve";
  static String rejectOffer(int id) => "$offerBase/$id/reject";
  static String expireOffer(int id) => "$offerBase/$id/expire";
  static String signOffer(int id) => "$offerBase/$id/sign";
  static String getCandidateOffers(int candidateId) =>
      "$offerBase/candidate/$candidateId";
  static String myOffer(int offerId) => "$offerBase/$offerId";

<<<<<<< HEAD
  // ------------------- Misc -------------------
  static String markNotificationRead(int notificationId) =>
      "$adminBase/notifications/$notificationId/read";
  static String searchAll(String query) => "$adminBase/search?q=$query";
  static String shortlistCandidates(int jobId) =>
      "$adminBase/jobs/$jobId/shortlist";
  static String shortlistExport(int jobId) =>
      "$adminBase/jobs/$jobId/shortlist/export";
=======
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
      "$analyticsBase/applications-per-requisition";
  static const getApplicationToInterviewConversion =
      "$analyticsBase/conversion/application-to-interview";
  static const getInterviewToOfferConversion =
      "$analyticsBase/conversion/interview-to-offer";
  static const getStageDropoff = "$analyticsBase/dropoff";
  static const getTimePerStage = "$analyticsBase/time-per-stage";
  static const getMonthlyApplications =
      "$analyticsBase/applications/monthly";
  static const getCVScreeningDrop =
      "$analyticsBase/cv-screening-drop";
  static const getAssessmentPassRate =
      "$analyticsBase/assessments/pass-rate";
  static const getInterviewScheduling =
      "$analyticsBase/interviews/scheduled";
  static const getOffersByCategory =
      "$analyticsBase/offers-by-category";
  static const getAvgCVScore =
      "$analyticsBase/candidate/avg-cv-score";
  static const getAvgAssessmentScore =
      "$analyticsBase/candidate/avg-assessment-score";
  static const getSkillsFrequency =
      "$analyticsBase/candidate/skills-frequency";
  static const getExperienceDistribution =
      "$analyticsBase/candidate/experience-distribution";

  // ==================== CANDIDATE ENDPOINTS ====================
  static const getCandidateProfile = "$candidateBase/profile";
  static const updateCandidateProfile = "$candidateBase/profile";
  static const uploadCandidateDocument = "$candidateBase/upload_document";
  static const uploadProfilePicture = "$candidateBase/upload_profile_picture";
  static const getCandidateSettings = "$candidateBase/settings";
  static const updateCandidateSettings = "$candidateBase/settings";
  static const changeCandidatePassword =
      "$candidateBase/settings/change_password";
  static const updateCandidateNotificationPreferences =
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
>>>>>>> 5650d70d9d92b0a6f6829a559a2e1d7d9d20ed77
}
