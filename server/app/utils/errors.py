class ApiException(Exception):
    \"\"\"Custom exception to represent API-level errors with an HTTP status code.\"\"\"
    def __init__(self, message: str, status_code: int = 400, payload: dict = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.payload = payload or {}

    def to_dict(self):
        rv = dict(self.payload)
        rv['error'] = self.message
        return rv


def handle_api_exception(e: ApiException):
    \"\"\"Convert ApiException to a JSON-serializable dict and status code.\"\"\"
    return e.to_dict(), e.status_code

