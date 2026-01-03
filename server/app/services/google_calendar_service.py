import os
import datetime
import pickle
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from flask import current_app
import uuid
import json

class GoogleCalendarService:
    """Google Calendar integration service"""
    
    # If modifying these scopes, delete the file token.pickle.
    SCOPES = ['https://www.googleapis.com/auth/calendar']
    
    def __init__(self):
        self.creds = None
        self.service = None
        
    def authenticate(self):
        """Authenticate and create Google Calendar service"""
        try:
            token_path = current_app.config.get('GOOGLE_CALENDAR_TOKEN_PATH', 'token.pickle')
            credentials_path = current_app.config.get('GOOGLE_CALENDAR_CREDENTIALS_PATH', 'credentials.json')
            
            if os.path.exists(token_path):
                with open(token_path, 'rb') as token:
                    self.creds = pickle.load(token)
            
            # If there are no (valid) credentials available, let the user log in.
            if not self.creds or not self.creds.valid:
                if self.creds and self.creds.expired and self.creds.refresh_token:
                    self.creds.refresh(Request())
                else:
                    if not os.path.exists(credentials_path):
                        current_app.logger.error(f"Google Calendar credentials not found at {credentials_path}")
                        return False
                    
                    flow = InstalledAppFlow.from_client_secrets_file(
                        credentials_path, self.SCOPES)
                    self.creds = flow.run_local_server(port=0)
                
                # Save the credentials for the next run
                with open(token_path, 'wb') as token:
                    pickle.dump(self.creds, token)
            
            self.service = build('calendar', 'v3', credentials=self.creds)
            return True
            
        except Exception as e:
            current_app.logger.error(f"Google Calendar authentication failed: {e}")
            return False
    
    def create_interview_event(self, interview_data, candidate_email, hiring_manager_email):
        """Create a Google Calendar event for an interview"""
        try:
            if not self.service:
                if not self.authenticate():
                    return None
            
            # Parse scheduled time
            scheduled_time_str = interview_data['scheduled_time']
            if 'Z' in scheduled_time_str:
                scheduled_time = datetime.datetime.fromisoformat(scheduled_time_str.replace('Z', '+00:00'))
            else:
                scheduled_time = datetime.datetime.fromisoformat(scheduled_time_str)
            
            # Calculate end time
            duration = current_app.config.get('GOOGLE_CALENDAR_DEFAULT_DURATION', 60)
            end_time = scheduled_time + datetime.timedelta(minutes=duration)
            
            # Generate unique ID for the event
            event_id = f"interview_{interview_data['id']}_{uuid.uuid4().hex[:8]}"
            
            # Build event description
            description = f"""
Interview Details:
- Candidate: {interview_data['candidate_name']}
- Position: {interview_data['job_title']}
- Type: {interview_data['interview_type']}
- Status: {interview_data['status']}

Meeting Link: {interview_data.get('meeting_link', 'To be provided')}

This interview was scheduled via the Recruitment Portal.
            """.strip()
            
            event = {
                'id': event_id,
                'summary': f"Interview: {interview_data['candidate_name']} - {interview_data['job_title']}",
                'description': description,
                'start': {
                    'dateTime': scheduled_time.isoformat(),
                    'timeZone': current_app.config.get('GOOGLE_CALENDAR_TIMEZONE', 'UTC'),
                },
                'end': {
                    'dateTime': end_time.isoformat(),
                    'timeZone': current_app.config.get('GOOGLE_CALENDAR_TIMEZONE', 'UTC'),
                },
                'attendees': [
                    {'email': candidate_email, 'responseStatus': 'needsAction'},
                    {'email': hiring_manager_email, 'responseStatus': 'accepted'}
                ],
                'reminders': {
                    'useDefault': False,
                    'overrides': [
                        {'method': 'email', 'minutes': 24 * 60},  # 1 day before
                        {'method': 'popup', 'minutes': 30},  # 30 minutes before
                    ],
                },
                'extendedProperties': {
                    'private': {
                        'interviewId': str(interview_data['id']),
                        'candidateId': str(interview_data['candidate_id']),
                        'applicationId': str(interview_data.get('application_id', '')),
                        'source': 'RecruitmentPortal'
                    }
                },
                'guestsCanInviteOthers': False,
                'guestsCanModify': False,
                'guestsCanSeeOtherGuests': True
            }
            
            # Add conference data for online interviews
            if interview_data.get('interview_type', '').lower() == 'online':
                event['conferenceData'] = {
                    'createRequest': {
                        'requestId': f"interview_{interview_data['id']}",
                        'conferenceSolutionKey': {'type': 'hangoutsMeet'},
                    },
                }
            
            # Insert the event
            event_result = self.service.events().insert(
                calendarId='primary',
                body=event,
                conferenceDataVersion=1 if interview_data.get('interview_type', '').lower() == 'online' else 0,
                sendUpdates='all'
            ).execute()
            
            current_app.logger.info(f"Google Calendar event created: {event_result.get('htmlLink')}")
            
            # Return event details
            return {
                'event_id': event_result['id'],
                'html_link': event_result.get('htmlLink'),
                'hangout_link': event_result.get('hangoutLink'),
                'conference_link': event_result.get('conferenceData', {}).get('entryPoints', [{}])[0].get('uri') if event_result.get('conferenceData') else None
            }
            
        except HttpError as e:
            current_app.logger.error(f"Google Calendar API error: {e}")
            return None
        except Exception as e:
            current_app.logger.error(f"Failed to create Google Calendar event: {e}")
            return None
    
    def update_interview_event(self, event_id, interview_data, candidate_email, hiring_manager_email):
        """Update an existing Google Calendar event"""
        try:
            if not self.service:
                if not self.authenticate():
                    return None
            
            # Get existing event
            event = self.service.events().get(
                calendarId='primary',
                eventId=event_id
            ).execute()
            
            # Parse new scheduled time
            scheduled_time_str = interview_data['scheduled_time']
            if 'Z' in scheduled_time_str:
                scheduled_time = datetime.datetime.fromisoformat(scheduled_time_str.replace('Z', '+00:00'))
            else:
                scheduled_time = datetime.datetime.fromisoformat(scheduled_time_str)
            
            duration = current_app.config.get('GOOGLE_CALENDAR_DEFAULT_DURATION', 60)
            end_time = scheduled_time + datetime.timedelta(minutes=duration)
            
            # Update event details
            event['summary'] = f"Interview (Rescheduled): {interview_data['candidate_name']} - {interview_data['job_title']}"
            event['description'] = f"""
Interview Details (Rescheduled):
- Candidate: {interview_data['candidate_name']}
- Position: {interview_data['job_title']}
- Type: {interview_data['interview_type']}
- Status: {interview_data['status']}

Meeting Link: {interview_data.get('meeting_link', 'To be provided')}

This interview was rescheduled via the Recruitment Portal.
            """.strip()
            
            event['start']['dateTime'] = scheduled_time.isoformat()
            event['end']['dateTime'] = end_time.isoformat()
            
            # Update attendees
            event['attendees'] = [
                {'email': candidate_email, 'responseStatus': 'needsAction'},
                {'email': hiring_manager_email, 'responseStatus': 'accepted'}
            ]
            
            # Update the event
            updated_event = self.service.events().update(
                calendarId='primary',
                eventId=event_id,
                body=event,
                sendUpdates='all'
            ).execute()
            
            current_app.logger.info(f"Google Calendar event updated: {updated_event.get('htmlLink')}")
            
            return {
                'event_id': updated_event['id'],
                'html_link': updated_event.get('htmlLink')
            }
            
        except HttpError as e:
            current_app.logger.error(f"Google Calendar API error on update: {e}")
            return None
        except Exception as e:
            current_app.logger.error(f"Failed to update Google Calendar event: {e}")
            return None
    
    def delete_interview_event(self, event_id):
        """Delete a Google Calendar event"""
        try:
            if not self.service:
                if not self.authenticate():
                    return False
            
            self.service.events().delete(
                calendarId='primary',
                eventId=event_id,
                sendUpdates='all'
            ).execute()
            
            current_app.logger.info(f"Google Calendar event deleted: {event_id}")
            return True
            
        except HttpError as e:
            if e.resp.status == 404:
                current_app.logger.warning(f"Google Calendar event not found (may already be deleted): {event_id}")
                return True
            current_app.logger.error(f"Google Calendar API error on delete: {e}")
            return False
        except Exception as e:
            current_app.logger.error(f"Failed to delete Google Calendar event: {e}")
            return False
    
    def get_interview_event(self, event_id):
        """Get a specific interview event"""
        try:
            if not self.service:
                if not self.authenticate():
                    return None
            
            event = self.service.events().get(
                calendarId='primary',
                eventId=event_id
            ).execute()
            
            return event
            
        except HttpError as e:
            if e.resp.status == 404:
                return None
            current_app.logger.error(f"Google Calendar API error getting event: {e}")
            return None
        except Exception as e:
            current_app.logger.error(f"Failed to get Google Calendar event: {e}")
            return None
    
    def get_user_events(self, time_min=None, time_max=None, max_results=100):
        """Get user's calendar events within a time range"""
        try:
            if not self.service:
                if not self.authenticate():
                    return []
            
            # Set default time range if not provided
            if not time_min:
                time_min = datetime.datetime.utcnow().isoformat() + 'Z'
            if not time_max:
                time_max = (datetime.datetime.utcnow() + datetime.timedelta(days=30)).isoformat() + 'Z'
            
            events_result = self.service.events().list(
                calendarId='primary',
                timeMin=time_min,
                timeMax=time_max,
                maxResults=max_results,
                singleEvents=True,
                orderBy='startTime'
            ).execute()
            
            events = events_result.get('items', [])
            
            # Filter for interview events
            interview_events = []
            for event in events:
                if event.get('extendedProperties', {}).get('private', {}).get('source') == 'RecruitmentPortal':
                    interview_events.append({
                        'event_id': event['id'],
                        'summary': event.get('summary'),
                        'description': event.get('description'),
                        'start': event['start'].get('dateTime', event['start'].get('date')),
                        'end': event['end'].get('dateTime', event['end'].get('date')),
                        'interview_id': event.get('extendedProperties', {}).get('private', {}).get('interviewId'),
                        'candidate_id': event.get('extendedProperties', {}).get('private', {}).get('candidateId'),
                        'html_link': event.get('htmlLink'),
                        'hangout_link': event.get('hangoutLink'),
                        'status': event.get('status')
                    })
            
            return interview_events
            
        except Exception as e:
            current_app.logger.error(f"Failed to fetch Google Calendar events: {e}")
            return []