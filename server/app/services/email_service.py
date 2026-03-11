from flask import render_template, current_app
from app.extensions import mail
from flask_mail import Message
from threading import Thread
from app.extensions import redis_client
import logging
import time
import socket


def _send_via_sendgrid_api(app, subject, recipients, html_body, text_body, sender):
    """Send one email via SendGrid v3 HTTP API. Returns True on success, False on failure."""
    api_key = (app.config.get("SENDGRID_API_KEY") or "").strip()
    if not api_key:
        return False
    url = (app.config.get("SENDGRID_API_URL") or "https://api.sendgrid.com/v3/mail/send").strip()
    # Parse sender: "Name <email>" or "email"
    from_email = sender
    from_name = None
    if sender and " <" in sender and sender.strip().endswith(">"):
        parts = sender.strip().rsplit(" <", 1)
        from_name = (parts[0] or "").strip() or None
        from_email = (parts[1] or "").rstrip(">").strip()
    # SendGrid requires: text/plain first, then text/html (see https://docs.sendgrid.com/api-reference/mail-send/mail-send)
    content = []
    if text_body and (text_body or "").strip():
        content.append({"type": "text/plain", "value": (text_body or "").strip()})
    content.append({"type": "text/html", "value": html_body or ""})
    payload = {
        "personalizations": [{"to": [{"email": r} for r in recipients], "subject": subject}],
        "from": {"email": from_email, "name": from_name} if from_name else {"email": from_email},
        "content": content,
    }
    try:
        import requests
        r = requests.post(
            url,
            json=payload,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            timeout=30,
        )
        if 200 <= r.status_code < 300:
            return True
        app.logger.warning("SendGrid API returned %s: %s", r.status_code, r.text[:500])
        return False
    except Exception as e:
        app.logger.warning("SendGrid API request failed: %s", e, exc_info=True)
        return False


def send_email_sync(app, subject, recipients, html_body, text_body=None):
    """
    Send one email synchronously: tries SendGrid API if SENDGRID_API_KEY is set,
    else SMTP with MAIL_TIMEOUT. Raises on failure. Call from within app_context.
    """
    sender = app.config.get("MAIL_DEFAULT_SENDER") or app.config.get("MAIL_USERNAME")
    if (app.config.get("SENDGRID_API_KEY") or "").strip():
        if _send_via_sendgrid_api(app, subject, recipients, html_body, text_body, sender):
            return
        # Fall through to SMTP on API failure
    timeout_seconds = max(30, int(app.config.get("MAIL_TIMEOUT") or 60))
    old_timeout = socket.getdefaulttimeout()
    try:
        socket.setdefaulttimeout(timeout_seconds)
        msg = Message(
            subject=subject,
            recipients=recipients,
            html=html_body,
            body=text_body or "",
            sender=sender,
        )
        mail.send(msg)
    finally:
        socket.setdefaulttimeout(old_timeout)


class EmailService:

    @staticmethod
    def send_verification_email(email, verification_code):
        """Send email verification code. Candidate receives the 6-digit code in the email."""
        subject = "Verify Your Email Address"
        app_url = (current_app.config.get("FRONTEND_URL") or "").rstrip("/") or "http://localhost:3000"
        try:
            html = render_template(
                'email_templates/verification_email.html',
                verification_code=verification_code,
                app_url=app_url,
            )
        except Exception:
            logging.error(f"Failed to render verification email template for {email}", exc_info=True)
            html = f"Your verification code is: {verification_code}. Enter it at {app_url}/verify-email"

        try:
            current_app.logger.info("Sending verification email to %s", email)
        except Exception:
            logging.info("Sending verification email to %s", email)
        EmailService.send_async_email(subject, [email], html)

    @staticmethod
    def send_verification_email_sync(email, verification_code):
        """
        Send verification email synchronously. Returns True if sent, False if failed
        (e.g. timeout). Use in register so we can return the code in response when email fails.
        """
        subject = "Verify Your Email Address"
        app_url = (current_app.config.get("FRONTEND_URL") or "").rstrip("/") or "http://localhost:3000"
        try:
            html = render_template(
                'email_templates/verification_email.html',
                verification_code=verification_code,
                app_url=app_url,
            )
        except Exception:
            logging.error("Failed to render verification email template for %s", email, exc_info=True)
            html = f"Your verification code is: {verification_code}. Enter it at {app_url}/verify-email"
        try:
            current_app.logger.info("Sending verification email to %s", email)
            send_email_sync(current_app._get_current_object(), subject, [email], html)
            return True
        except Exception as e:
            logging.warning("Verification email send failed for %s: %s", email, e, exc_info=True)
            return False

    @staticmethod
    def send_password_reset_email(email, reset_token):
        """Send password reset instructions."""
        subject = "Password Reset Request"
        base = current_app.config.get("FRONTEND_URL") or "http://localhost:3000"
        reset_link = f"{base.rstrip('/')}/reset-password?token={reset_token}"
        try:
            html = render_template(
                'email_templates/password_reset_email.html', 
                reset_link=reset_link
            )
        except Exception:
            logging.error(f"Failed to render password reset template for {email}", exc_info=True)
            html = f"Reset your password using this link: {reset_link}"

        EmailService.send_async_email(subject, [email], html)

    @staticmethod
    def send_interview_invitation(email, candidate_name, interview_date, interview_type, meeting_link=None, calendar_link=None):
        """Send interview invitation email with calendar integration."""
        subject = "Interview Invitation"
        try:
            html = render_template(
                'email_templates/interview_invitation.html',
                candidate_name=candidate_name,
                interview_date=interview_date,
                interview_type=interview_type,
                meeting_link=meeting_link,
                calendar_link=calendar_link
            )
            text_body = f"Hi {candidate_name},\n\nYour {interview_type} interview is scheduled on {interview_date}.\n"
            if meeting_link:
                text_body += f"Meeting Link: {meeting_link}\n"
            if calendar_link:
                text_body += f"Add to Calendar: {calendar_link}\n"
        except Exception:
            logging.error(f"Failed to render interview invitation template for {email}", exc_info=True)

            # Plain text fallback
            text_body = f"Hi {candidate_name}, your {interview_type} interview is scheduled on {interview_date}. Link: {meeting_link or 'N/A'}"
            if calendar_link:
                text_body += f"\nCalendar Link: {calendar_link}"

            # Convert to basic HTML with clickable links
            html = "".join(f"<p>{line}</p>" for line in text_body.split("\n"))
            if meeting_link:
                html += f'<p>Meeting Link: <a href="{meeting_link}">{meeting_link}</a></p>'
            if calendar_link:
                html += f'<p>Add to Calendar: <a href="{calendar_link}">{calendar_link}</a></p>'

        EmailService.send_async_email(subject, [email], html, text_body=text_body)



    @staticmethod
    def send_application_status_update(email, candidate_name, status, position_title):
        """Send application status update email."""
        subject = f"Application Update for {position_title or 'your position'}"
        try:
            html = render_template(
                'email_templates/application_status_update.html',
                candidate_name=candidate_name,
                status=status,
                position_title=position_title
            )
        except Exception:
            logging.error(f"Failed to render application status update template for {email}", exc_info=True)
            html = f"Hi {candidate_name}, your application for {position_title} status is: {status}"

        EmailService.send_async_email(subject, [email], html)

    @staticmethod
    def send_temporary_password(email, password, first_name=None):
        """Send enrollment email with temporary password."""
        subject = "Your Temporary Password"

        try:
            html = render_template(
                'email_templates/temporary_password.html',
                password=password,
                first_name=first_name,
                current_year=2025
            )
            text_body = f"Hello {first_name or ''},\n\nYour temporary password is: {password}"
        except Exception:
            logging.error(f"Failed to render temporary password template for {email}", exc_info=True)
            html = text_body = f"Your temporary password is: {password}"

        EmailService.send_async_email(subject, [email], html, text_body=text_body)
        
    @staticmethod
    def send_async_email(subject, recipients, html_body, text_body=None):
        """Send email in a background thread safely. Uses request app when available so mail config/state is correct."""
        from flask import current_app
        from app import create_app
        try:
            app = current_app._get_current_object()
        except RuntimeError:
            app = create_app()

        # Ensure subject is a string
        subject = str(subject)

        def send_email(app, subject, recipients, html_body, text_body):
            logger = app.logger
            sender = app.config.get('MAIL_DEFAULT_SENDER') or app.config.get('MAIL_USERNAME')
            # Prefer SendGrid HTTP API when configured (avoids SMTP connect timeouts from cloud)
            if (app.config.get("SENDGRID_API_KEY") or "").strip():
                try:
                    with app.app_context():
                        if _send_via_sendgrid_api(app, subject, recipients, html_body, text_body, sender):
                            logger.info("Email sent successfully to %s via SendGrid API", recipients)
                            return
                except Exception as e:
                    logger.warning("SendGrid API send failed for %s: %s; falling back to SMTP", recipients, e)
            # SMTP path: use longer timeout so Render → SendGrid connect can complete
            timeout_seconds = max(30, int(app.config.get("MAIL_TIMEOUT") or 60))
            max_attempts = 3
            retry_delay_seconds = 5
            last_error = None
            for attempt in range(1, max_attempts + 1):
                try:
                    with app.app_context():
                        old_timeout = socket.getdefaulttimeout()
                        try:
                            socket.setdefaulttimeout(timeout_seconds)
                            msg = Message(
                                subject=subject,
                                recipients=recipients,
                                html=html_body,
                                body=text_body or "",
                                sender=sender
                            )
                            mail.send(msg)
                        finally:
                            socket.setdefaulttimeout(old_timeout)
                    logger.info("Email sent successfully to %s (attempt %d)", recipients, attempt)
                    return
                except Exception as e:
                    last_error = e
                    logger.warning(
                        "Send attempt %d/%d failed for %s: %s (type=%s)",
                        attempt, max_attempts, recipients, str(e), type(e).__name__,
                    )
                    if attempt < max_attempts:
                        time.sleep(retry_delay_seconds)
            logger.error(
                "Failed to send email to %s after %d attempts: %s (type=%s). Check MAIL_* / SENDGRID_API_KEY and sender verification.",
                recipients, max_attempts, str(last_error), type(last_error).__name__,
                exc_info=True,
            )

        thread = Thread(target=send_email, args=[app, subject, recipients, html_body, text_body])
        thread.start()
        
    @staticmethod
    def send_interview_cancellation(email, candidate_name, interview_date, interview_type, reason=None):
        """
        Send email notification that an interview has been cancelled.
        Includes optional reason and always provides HTML + plain text.
        """
        subject = "Interview Cancellation Notice"
    
        # Ensure reason is a string
        reason_text = reason or "No specific reason provided."
    
        try:
            html = render_template(
                'email_templates/interview_cancellation.html',
                candidate_name=candidate_name,
                interview_date=interview_date,
                interview_type=interview_type,
                reason=reason_text
            )
            text_body = f"Hi {candidate_name},\n\nYour {interview_type} interview scheduled on {interview_date} has been cancelled.\nReason: {reason_text}\n\nPlease contact us for rescheduling."
        except Exception:
            logging.error(f"Failed to render interview cancellation template for {email}", exc_info=True)
            html = text_body = f"Hi {candidate_name}, your {interview_type} interview scheduled on {interview_date} has been cancelled.\nReason: {reason_text}"

        EmailService.send_async_email(subject, [email], html, text_body=text_body)
        
    @staticmethod
    def send_interview_reschedule_email(email, candidate_name, old_time, new_time, interview_type, meeting_link=None, calendar_link=None):
        """Send interview reschedule notification."""
        subject = "Interview Rescheduled"
        try:
            html = render_template(
                "email_templates/interview_reschedule.html",
                candidate_name=candidate_name,
                old_time=old_time,
                new_time=new_time,
                interview_type=interview_type,
                meeting_link=meeting_link,
                calendar_link=calendar_link
            )
            text_body = f"Hi {candidate_name},\n\nYour {interview_type} interview has been rescheduled from {old_time} to {new_time}.\n"
            if meeting_link:
                text_body += f"Meeting Link: {meeting_link}\n"
            if calendar_link:
                text_body += f"Updated Calendar: {calendar_link}\n"
        except Exception:
            logging.error(f"Failed to render reschedule email template for {email}", exc_info=True)
            html = text_body = f"Hi {candidate_name}, your {interview_type} interview has been rescheduled from {old_time} to {new_time}."

        EmailService.send_async_email(subject, [email], html, text_body=text_body)
        
        
    @staticmethod
    def send_offer_email(candidate_email, offer_pdf_url, candidate_name, offer_details=None):
        """
        Send the offer email with a PDF or DOC attachment link.
        offer_details: dict containing summary info like base_salary, contract_type, etc.
        """
        subject = "Your Job Offer"
        try:
            html = render_template(
                'email_templates/offer_email.html',
                candidate_name=candidate_name,
                offer_url=offer_pdf_url,
                offer_details=offer_details
            )
            text_body = f"Hi {candidate_name},\n\nYour job offer is ready. Download it here: {offer_pdf_url}"
        except Exception:
            logging.error(f"Failed to render offer email template for {candidate_email}", exc_info=True)
            html = text_body = f"Hi {candidate_name}, your offer is available here: {offer_pdf_url}"

        EmailService.send_async_email(subject, [candidate_email], html, text_body=text_body)

    @staticmethod
    def send_offer_signed_confirmation(candidate_email, candidate_name):
        """Send confirmation once candidate signs the offer."""
        subject = "Offer Signed Successfully"
        try:
            html = render_template(
                'email_templates/offer_signed.html',
                candidate_name=candidate_name
            )
            text_body = f"Hi {candidate_name},\n\nWe have received your signed offer. Welcome aboard!"
        except Exception:
            logging.error(f"Failed to render offer signed template for {candidate_email}", exc_info=True)
            html = text_body = f"Hi {candidate_name}, your signed offer has been received. Welcome!"

        EmailService.send_async_email(subject, [candidate_email], html, text_body=text_body)

    @staticmethod
    def send_interview_completion_email(email, candidate_name, interview_date):
        """Send email to candidate after interview completion"""
        subject = "Thank You for Your Interview"
        
        try:
            html = render_template(
                'email_templates/interview_completion.html',
                candidate_name=candidate_name,
                interview_date=interview_date
            )
            text_body = f"""Dear {candidate_name},

Thank you for participating in our interview process. Your interview on {interview_date} has been marked as completed.

Our hiring team will review your feedback and be in touch regarding next steps within the next few business days.

Best regards,
The Hiring Team"""
        except Exception:
            logging.error(f"Failed to render interview completion template for {email}", exc_info=True)
            html = text_body = f"""Dear {candidate_name},

Thank you for completing your interview on {interview_date}. Our team will review and get back to you soon.

Best regards,
The Hiring Team"""

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_interview_reminder(email, candidate_name, interview_date, interview_type, 
                               meeting_link, reminder_type, timezone="UTC"):
        """Send interview reminder to candidate"""
        hours = "24 hours" if reminder_type == "24_hours" else "1 hour"
        subject = f"Interview Reminder: {hours} to go"
        
        try:
            html = render_template(
                'email_templates/interview_reminder.html',
                candidate_name=candidate_name,
                interview_date=interview_date,
                interview_type=interview_type,
                meeting_link=meeting_link,
                reminder_type=reminder_type,
                hours=hours,
                timezone=timezone
            )
            text_body = f"""Dear {candidate_name},

This is a reminder that your {interview_type} interview is scheduled for:

Date: {interview_date} ({timezone})

Meeting Link: {meeting_link}

Please ensure you:
1. Test your audio/video equipment
2. Have a stable internet connection
3. Are in a quiet, well-lit environment
4. Have your resume and any required materials ready

Best regards,
The Hiring Team"""
        except Exception:
            logging.error(f"Failed to render interview reminder template for {email}", exc_info=True)
            html = text_body = f"""Dear {candidate_name},

Reminder: Your {interview_type} interview is in {hours} ({interview_date}).
Meeting Link: {meeting_link}

Best regards,
The Hiring Team"""

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_interviewer_reminder(email, interviewer_name, candidate_name, interview_date, 
                                 interview_type, meeting_link, reminder_type, timezone="UTC"):
        """Send interview reminder to interviewer"""
        hours = "24 hours" if reminder_type == "24_hours" else "1 hour"
        subject = f"Interview Reminder: {hours} to go with {candidate_name}"
        
        try:
            html = render_template(
                'email_templates/interviewer_reminder.html',
                interviewer_name=interviewer_name,
                candidate_name=candidate_name,
                interview_date=interview_date,
                interview_type=interview_type,
                meeting_link=meeting_link,
                reminder_type=reminder_type,
                hours=hours,
                timezone=timezone
            )
            text_body = f"""Dear {interviewer_name},

Reminder: You have an interview scheduled with {candidate_name}

Time: {interview_date} ({timezone})
Type: {interview_type}

Meeting Link: {meeting_link}

Candidate Details:
Name: {candidate_name}

Please review the candidate's profile before the interview.

Best regards,
Hiring Team"""
        except Exception:
            logging.error(f"Failed to render interviewer reminder template for {email}", exc_info=True)
            html = text_body = f"""Dear {interviewer_name},

Reminder: Interview with {candidate_name} in {hours}.
Time: {interview_date}
Link: {meeting_link}

Best regards,
Hiring Team"""

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_feedback_confirmation(email, interviewer_name, candidate_name, interview_date):
        """Send confirmation email after feedback submission"""
        subject = "Interview Feedback Submitted"
        
        try:
            html = render_template(
                'email_templates/feedback_confirmation.html',
                interviewer_name=interviewer_name,
                candidate_name=candidate_name,
                interview_date=interview_date
            )
            text_body = f"""Dear {interviewer_name},

Thank you for submitting your feedback for the interview with {candidate_name} on {interview_date}.

Your feedback has been recorded and will be reviewed by the hiring team.

Best regards,
The Hiring Team"""
        except Exception:
            logging.error(f"Failed to render feedback confirmation template for {email}", exc_info=True)
            html = text_body = f"""Dear {interviewer_name},

Thank you for submitting feedback for {candidate_name}'s interview on {interview_date}.

Best regards,
The Hiring Team"""

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_feedback_request_email(email, interviewer_name, candidate_name, interview_date, feedback_link=None):
        """Send email requesting interview feedback"""
        subject = f"Feedback Request: Interview with {candidate_name}"
        
        try:
            html = render_template(
                'email_templates/feedback_request.html',
                interviewer_name=interviewer_name,
                candidate_name=candidate_name,
                interview_date=interview_date,
                feedback_link=feedback_link
            )
            text_body = f"""Dear {interviewer_name},

Please submit your feedback for the interview with {candidate_name} on {interview_date}."""
            
            if feedback_link:
                text_body += f"\n\nSubmit feedback here: {feedback_link}"
            
            text_body += "\n\nThank you,\nThe Hiring Team"
                
        except Exception:
            logging.error(f"Failed to render feedback request template for {email}", exc_info=True)
            text_body = f"Dear {interviewer_name}, please submit feedback for {candidate_name}'s interview on {interview_date}"
            if feedback_link:
                text_body += f"\nLink: {feedback_link}"
            html = text_body

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_interview_no_show_email(email, candidate_name, interview_date, contact_email=None, contact_phone=None):
        """Send email to hiring team about candidate no-show"""
        subject = f"Candidate No-Show: {candidate_name}"
        
        try:
            html = render_template(
                'email_templates/interview_no_show.html',
                candidate_name=candidate_name,
                interview_date=interview_date,
                contact_email=contact_email,
                contact_phone=contact_phone
            )
            text_body = f"""Candidate No-Show Alert:

Candidate: {candidate_name}
Scheduled Interview: {interview_date}
Status: No-Show

The candidate did not attend the scheduled interview."""
            
            if contact_email or contact_phone:
                text_body += "\n\nCandidate Contact Info:"
                if contact_email:
                    text_body += f"\nEmail: {contact_email}"
                if contact_phone:
                    text_body += f"\nPhone: {contact_phone}"
                    
            text_body += "\n\nPlease follow up with the candidate or mark as no-show in the system."
            
        except Exception:
            logging.error(f"Failed to render no-show email template for {email}", exc_info=True)
            html = text_body = f"Candidate {candidate_name} was a no-show for interview on {interview_date}."

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_interview_cancelled_by_candidate_email(email, candidate_name, interview_date, reason=None, contact_email=None):
        """Send notification that candidate cancelled interview"""
        subject = f"Interview Cancelled by Candidate: {candidate_name}"
        
        try:
            html = render_template(
                'email_templates/interview_cancelled_by_candidate.html',
                candidate_name=candidate_name,
                interview_date=interview_date,
                reason=reason,
                contact_email=contact_email
            )
            text_body = f"""Interview Cancellation Alert:

Candidate: {candidate_name}
Scheduled Interview: {interview_date}
Status: Cancelled by Candidate
Reason: {reason or 'Not specified'}"""
            
            if contact_email:
                text_body += f"\nCandidate Email: {contact_email}"
                
            text_body += "\n\nThe interview has been cancelled in the system. Please review the candidate's application."
            
        except Exception:
            logging.error(f"Failed to render candidate cancellation email template for {email}", exc_info=True)
            html = text_body = f"Candidate {candidate_name} cancelled interview on {interview_date}. Reason: {reason}"

        EmailService.send_async_email(subject, [email], html, text_body=text_body)

    @staticmethod
    def send_interview_feedback_summary_email(email, candidate_name, interview_date, 
                                            average_rating, recommendations, hiring_manager_name=None):
        """Send summary of all interview feedback to hiring manager"""
        subject = f"Interview Feedback Summary: {candidate_name}"
        
        # Format recommendations for display
        recommendation_text = ", ".join(recommendations) if recommendations else "No recommendations yet"
        
        try:
            html = render_template(
                'email_templates/feedback_summary.html',
                candidate_name=candidate_name,
                interview_date=interview_date,
                average_rating=average_rating,
                recommendations=recommendation_text,
                hiring_manager_name=hiring_manager_name
            )
            text_body = f"""Interview Feedback Summary:

Candidate: {candidate_name}
Interview Date: {interview_date}
Average Rating: {average_rating:.1f}/5.0
Recommendations: {recommendation_text}

All feedback has been submitted. Please review and proceed with next steps."""
            
            if hiring_manager_name:
                text_body = f"Dear {hiring_manager_name},\n\n" + text_body
                
        except Exception:
            logging.error(f"Failed to render feedback summary template for {email}", exc_info=True)
            html = text_body = f"""Interview feedback summary for {candidate_name}:
Date: {interview_date}
Average Rating: {average_rating}
Recommendations: {recommendation_text}"""

        EmailService.send_async_email(subject, [email], html, text_body=text_body)
