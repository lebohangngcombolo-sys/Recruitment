"""
Autofill Data Schema for CV Analyser
Defines the response format for direct recruitment app integration.
"""

from __future__ import annotations
from typing import List, Optional
from pydantic import BaseModel, Field


class PersonalInfo(BaseModel):
    """Personal information for autofill."""
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    dob: Optional[str] = None
    gender: Optional[str] = None
    linkedin: Optional[str] = None
    github: Optional[str] = None
    portfolio: Optional[str] = None


class EducationInfo(BaseModel):
    """Education information for autofill."""
    degree: Optional[str] = None
    university: Optional[str] = None
    year: Optional[str] = None
    field: Optional[str] = None


class ExperienceInfo(BaseModel):
    """Work experience information for autofill."""
    title: Optional[str] = None
    company: Optional[str] = None
    period: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None


class AutofillData(BaseModel):
    """Complete autofill data structure for recruitment app integration."""
    personal: PersonalInfo = Field(default_factory=PersonalInfo)
    education: List[EducationInfo] = Field(default_factory=list)
    skills: List[str] = Field(default_factory=list)
    experience: List[ExperienceInfo] = Field(default_factory=list)
    certifications: List[str] = Field(default_factory=list)
    languages: List[str] = Field(default_factory=list)
    
    class Config:
        json_encoders = {
            # Add any custom encoders if needed
        }


class AnalyzeFileRequest(BaseModel):
    """Request model for file-based CV analysis."""
    job_description: Optional[str] = Field(None, description="Job description for scoring")
    industry: Optional[str] = Field(None, description="Industry context")
    include_autofill: bool = Field(True, description="Include autofill data in response")


class AnalyzeFileResponse(BaseModel):
    """Response model for file-based CV analysis."""
    analysis_id: str
    status: str
    message: Optional[str] = None
