import 'package:flutter/material.dart';

enum OfferStatus {
  draft,
  reviewed,
  approved,
  sent,
  signed,
  rejected,
  expired,
  withdrawn
}

class Offer {
  final int? id;
  final int applicationId;
  final String status;
  final String? draftedBy;
  final String? hiringManagerId;
  final String? approvedBy;
  final String? signedBy;
  final double? baseSalary;
  final Map<String, dynamic>? allowances;
  final Map<String, dynamic>? bonuses;
  final String? contractType;
  final DateTime? startDate;
  final String? workLocation;
  final String? notes;
  final String? pdfUrl;
  final DateTime? pdfGeneratedAt;
  final DateTime? signedAt;
  final String? candidateIp;
  final String? candidateUserAgent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? offerVersion;

  // Additional fields for display
  final String? candidateName;
  final String? jobTitle;
  final DateTime? expiresAt;
  String? priority; // Add this

  Offer(
      {this.id,
      required this.applicationId,
      required this.status,
      this.draftedBy,
      this.hiringManagerId,
      this.approvedBy,
      this.signedBy,
      this.baseSalary,
      this.allowances,
      this.bonuses,
      this.contractType,
      this.startDate,
      this.workLocation,
      this.notes,
      this.pdfUrl,
      this.pdfGeneratedAt,
      this.signedAt,
      this.candidateIp,
      this.candidateUserAgent,
      this.createdAt,
      this.updatedAt,
      this.offerVersion,
      this.candidateName,
      this.jobTitle,
      this.expiresAt});

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'],
      applicationId: json['application_id'],
      status: json['status'],
      draftedBy: json['drafted_by'],
      hiringManagerId: json['hiring_manager_id'],
      approvedBy: json['approved_by'],
      signedBy: json['signed_by'],
      baseSalary: json['base_salary'] != null
          ? double.tryParse(json['base_salary'].toString())
          : null,
      allowances: json['allowances'] != null
          ? (json['allowances'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0.0),
            )
          : null,
      bonuses: json['bonuses'] != null
          ? (json['bonuses'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0.0),
            )
          : null,
      contractType: json['contract_type'],
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      workLocation: json['work_location'],
      notes: json['notes'],
      pdfUrl: json['pdf_url'],
      pdfGeneratedAt: json['pdf_generated_at'] != null
          ? DateTime.parse(json['pdf_generated_at'])
          : null,
      signedAt:
          json['signed_at'] != null ? DateTime.parse(json['signed_at']) : null,
      candidateIp: json['candidate_ip'],
      candidateUserAgent: json['candidate_user_agent'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      offerVersion: json['offer_version'],
      candidateName: json['candidate_name'],
      jobTitle: json['job_title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'application_id': applicationId,
      'base_salary': baseSalary,
      'allowances': allowances,
      'bonuses': bonuses,
      'contract_type': contractType,
      'start_date': startDate?.toIso8601String(),
      'work_location': workLocation,
      'notes': notes,
    };
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'reviewed':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'sent':
        return 'Sent to Candidate';
      case 'signed':
        return 'Signed';
      case 'rejected':
        return 'Rejected';
      case 'expired':
        return 'Expired';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'sent':
        return Colors.purple;
      case 'signed':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'withdrawn':
        return Colors.brown;
      default:
        return Colors.black;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'draft':
        return Icons.drafts;
      case 'reviewed':
        return Icons.reviews;
      case 'approved':
        return Icons.check_circle;
      case 'sent':
        return Icons.send;
      case 'signed':
        return Icons.assignment_turned_in;
      case 'rejected':
        return Icons.cancel;
      case 'expired':
        return Icons.timelapse;
      case 'withdrawn':
        return Icons.undo;
      default:
        return Icons.description;
    }
  }

  Offer copyWith({
    int? id,
    int? applicationId,
    String? status,
    String? draftedBy,
    String? hiringManagerId,
    String? approvedBy,
    String? signedBy,
    double? baseSalary,
    Map<String, dynamic>? allowances,
    Map<String, dynamic>? bonuses,
    String? contractType,
    DateTime? startDate,
    String? workLocation,
    String? notes,
    String? pdfUrl,
    DateTime? pdfGeneratedAt,
    DateTime? signedAt,
    String? candidateIp,
    String? candidateUserAgent,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? offerVersion,
    String? candidateName,
    String? jobTitle,
  }) {
    return Offer(
      id: id ?? this.id,
      applicationId: applicationId ?? this.applicationId,
      status: status ?? this.status,
      draftedBy: draftedBy ?? this.draftedBy,
      hiringManagerId: hiringManagerId ?? this.hiringManagerId,
      approvedBy: approvedBy ?? this.approvedBy,
      signedBy: signedBy ?? this.signedBy,
      baseSalary: baseSalary ?? this.baseSalary,
      allowances: allowances ?? this.allowances,
      bonuses: bonuses ?? this.bonuses,
      contractType: contractType ?? this.contractType,
      startDate: startDate ?? this.startDate,
      workLocation: workLocation ?? this.workLocation,
      notes: notes ?? this.notes,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfGeneratedAt: pdfGeneratedAt ?? this.pdfGeneratedAt,
      signedAt: signedAt ?? this.signedAt,
      candidateIp: candidateIp ?? this.candidateIp,
      candidateUserAgent: candidateUserAgent ?? this.candidateUserAgent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      offerVersion: offerVersion ?? this.offerVersion,
      candidateName: candidateName ?? this.candidateName,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }
}
