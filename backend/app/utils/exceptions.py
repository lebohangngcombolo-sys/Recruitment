class ServiceException(Exception):
    """Base exception for service layer"""
    def __init__(self, message, code=400, details=None):
        super().__init__(message)
        self.code = code
        self.details = details

class ValidationException(ServiceException):
    """Validation exception"""
    def __init__(self, message, details=None):
        super().__init__(message, code=422, details=details)

class NotFoundException(ServiceException):
    """Resource not found exception"""
    def __init__(self, resource, resource_id):
        super().__init__(f"{resource} with id {resource_id} not found", code=404)

class ConflictException(ServiceException):
    """Conflict exception"""
    def __init__(self, message, details=None):
        super().__init__(message, code=409, details=details)

class UnauthorizedException(ServiceException):
    """Unauthorized access exception"""
    def __init__(self, message="Unauthorized access"):
        super().__init__(message, code=403)