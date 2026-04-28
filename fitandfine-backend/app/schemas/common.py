from typing import Generic, Optional, TypeVar
from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


class APIResponse(BaseModel, Generic[T]):
    """Standard API envelope."""
    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None

    model_config = ConfigDict(arbitrary_types_allowed=True)


class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int
    has_more: bool


class ErrorResponse(BaseModel):
    success: bool = False
    error: str
    detail: Optional[str] = None
