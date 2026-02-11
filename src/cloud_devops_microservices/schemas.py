from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class OrderBase(BaseModel):
    item_name: str
    quantity: int
    price: float


class OrderCreate(OrderBase):
    pass


class OrderUpdate(BaseModel):
    item_name: Optional[str] = None
    quantity: Optional[int] = None
    price: Optional[float] = None


class OrderRead(OrderBase):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True
