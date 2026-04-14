"""
Enhanced Skills Extraction Service
Provides context-aware skill detection with confidence scoring and categorization.
"""

import re
from typing import List, Dict, Any, Tuple
from collections import defaultdict
import logging

logger = logging.getLogger(__name__)


class EnhancedSkillsExtractor:
    """Advanced skills extraction with context awareness and ML-based enhancement."""
    
    def __init__(self):
        # Comprehensive skills library with categories and confidence weights
        self.skills_library = {
            'programming': {
                'skills': [
                    'python', 'java', 'javascript', 'typescript', 'c++', 'c#', 'go', 'rust',
                    'php', 'ruby', 'swift', 'kotlin', 'scala', 'perl', 'r', 'matlab'
                ],
                'confidence_weight': 0.9,
                'context_patterns': [r'programming\s+languages?', r'coding\s+skills?']
            },
            'web_development': {
                'skills': [
                    'html', 'css', 'react', 'vue', 'angular', 'node.js', 'nodejs', 'express', 
                    'django', 'flask', 'fastapi', 'spring', 'laravel', 'rails', 'next.js', 
                    'webpack', 'tailwind', 'bootstrap', 'sass', 'graphql'
                ],
                'confidence_weight': 0.85,
                'context_patterns': [r'web\s+tech', r'frontend', r'backend']
            },
            'databases': {
                'skills': [
                    'sql', 'mysql', 'postgresql', 'mongodb', 'redis', 'elasticsearch',
                    'oracle', 'sql server', 'sqlite', 'cassandra', 'dynamodb', 'firebase'
                ],
                'confidence_weight': 0.9,
                'context_patterns': [r'databases?', r'data\s+storage']
            },
            'cloud_devops': {
                'skills': [
                    'aws', 'azure', 'gcp', 'google cloud', 'docker', 'kubernetes', 'jenkins',
                    'gitlab ci', 'github actions', 'terraform', 'ansible', 'kubernetes', 'k8s'
                ],
                'confidence_weight': 0.85,
                'context_patterns': [r'cloud\s+platforms?', r'devops']
            },
            'soft_skills': {
                'skills': [
                    'leadership', 'communication', 'teamwork', 'problem solving', 
                    'critical thinking', 'time management', 'project management', 
                    'agile', 'scrum', 'collaboration', 'presentation'
                ],
                'confidence_weight': 0.7,
                'context_patterns': [r'soft\s+skills?', r'competencies?']
            }
        }
        
        # Skill level indicators
        self.level_indicators = {
            'expert': ['expert', 'senior', 'lead', 'principal', 'architect'],
            'intermediate': ['intermediate', 'mid-level', 'proficient'],
            'beginner': ['beginner', 'junior', 'familiar']
        }
        
        self.skill_synonyms = {
            'javascript': ['js', 'ecmascript'],
            'typescript': ['ts'],
            'python': ['python3'],
            'node.js': ['nodejs'],
            'aws': ['amazon web services'],
            'c++': ['cpp'],
            'c#': ['csharp']
        }

    def extract_skills(self, text: str, context_data: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        if not text or not isinstance(text, str):
            return []
        
        all_matches = []
        text_lower = text.lower()
        
        # 1. Direct matching with word boundaries
        for category, data in self.skills_library.items():
            for skill in data['skills']:
                # Escape for regex and use word boundaries
                pattern = rf'\b{re.escape(skill.lower())}\b'
                if re.search(pattern, text_lower):
                    all_matches.append({
                        'name': skill,
                        'category': category,
                        'confidence': self._calculate_confidence(skill, text_lower, data),
                        'extraction_method': 'direct_match'
                    })
        
        # 2. Synonym matching
        for canonical, synonyms in self.skill_synonyms.items():
            if any(skill['name'].lower() == canonical.lower() for skill in all_matches):
                continue # Already found
            for syn in synonyms:
                if re.search(rf'\b{re.escape(syn.lower())}\b', text_lower):
                    all_matches.append({
                        'name': canonical,
                        'category': self._find_category(canonical),
                        'confidence': 0.8,
                        'extraction_method': 'synonym_match'
                    })
        
        # 3. List parsing from common sections
        patterns = [r'skills?:?\s*([^\n]+)', r'competencies?:?\s*([^\n]+)']
        for p in patterns:
            match = re.search(p, text_lower)
            if match:
                items = re.split(r'[,;•\n]|(?:\s+and\s+)', match.group(1))
                for item in items:
                    item = item.strip().title()
                    # Filter out noise: too short, too long, or starts with common prepositions
                    if 2 < len(item) < 40:
                        if item.lower().split()[0] in ['in', 'and', 'with', 'the', 'using', 'from']:
                            continue
                        if not any(m['name'].lower() == item.lower() for m in all_matches):
                            all_matches.append({
                                'name': item,
                                'category': 'other',
                                'confidence': 0.6,
                                'extraction_method': 'list_parsing'
                            })
        
        # Deduplicate and prioritize high-confidence matches
        seen = {}
        for s in all_matches:
            name_lower = s['name'].lower()
            if name_lower not in seen or s['confidence'] > seen[name_lower]['confidence']:
                seen[name_lower] = s
        
        return list(seen.values())[:50]

    def _calculate_confidence(self, skill: str, text: str, data: Dict) -> float:
        conf = data.get('confidence_weight', 0.8)
        # Boost if mentions "expert" or "senior" nearby (simple check)
        if re.search(rf'(?:expert|senior|lead|proficient)\s+(?:in|with|at)?\s*{re.escape(skill)}', text, re.I):
            conf += 0.1
        return min(conf, 1.0)

    def _find_category(self, skill_name: str) -> str:
        for cat, data in self.skills_library.items():
            if skill_name.lower() in [s.lower() for s in data['skills']]:
                return cat
        return 'other'
