"""Custom exceptions for the application."""


class DomainException(Exception):
    """Base exception for domain layer."""

    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)


class NotFoundError(DomainException):
    """Raised when a resource is not found."""

    pass


class ValidationError(DomainException):
    """Raised when validation fails."""

    pass


class ServerError(Exception):
    """Raised for server-side errors."""

    def __init__(self, message: str, status_code: int = 500):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)
