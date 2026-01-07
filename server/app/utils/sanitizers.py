import html
import bleach
from markdown import markdown

def sanitize_html(text):
    """Sanitize HTML input"""
    if not text:
        return text
    
    # Allow only safe tags and attributes
    allowed_tags = bleach.sanitizer.ALLOWED_TAGS + ['p', 'br', 'h1', 'h2', 'h3', 'h4', 'ul', 'ol', 'li']
    allowed_attrs = bleach.sanitizer.ALLOWED_ATTRIBUTES
    
    return bleach.clean(
        text,
        tags=allowed_tags,
        attributes=allowed_attrs,
        strip=True
    )

def sanitize_text(text):
    """Sanitize plain text input"""
    if isinstance(text, str):
        # Escape HTML, remove excessive whitespace
        text = html.escape(text.strip())
        # Remove multiple spaces
        text = ' '.join(text.split())
    return text

def sanitize_list(items):
    """Sanitize list of strings"""
    if isinstance(items, list):
        return [sanitize_text(item) for item in items if isinstance(item, str)]
    return items

def sanitize_dict(data):
    """Recursively sanitize dictionary"""
    if isinstance(data, dict):
        return {key: sanitize_value(value) for key, value in data.items()}
    return data

def sanitize_value(value):
    """Sanitize any value type"""
    if isinstance(value, str):
        return sanitize_text(value)
    elif isinstance(value, list):
        return sanitize_list(value)
    elif isinstance(value, dict):
        return sanitize_dict(value)
    else:
        return value

def markdown_to_safe_html(markdown_text):
    """Convert markdown to safe HTML"""
    if not markdown_text:
        return ""
    
    # Convert markdown to HTML
    html_text = markdown(markdown_text)
    
    # Sanitize the HTML
    return sanitize_html(html_text)