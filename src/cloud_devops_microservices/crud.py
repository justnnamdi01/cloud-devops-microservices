from sqlalchemy.orm import Session
from . import models, schemas
from typing import List, Optional


def get_order(db: Session, order_id: int) -> Optional[models.Order]:
    return db.query(models.Order).filter(models.Order.id == order_id).first()


def get_orders(db: Session, skip: int = 0, limit: int = 100) -> List[models.Order]:
    return db.query(models.Order).offset(skip).limit(limit).all()


def create_order(db: Session, order_in: schemas.OrderCreate) -> models.Order:
    db_obj = models.Order(
        item_name=order_in.item_name, quantity=order_in.quantity, price=order_in.price
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj


def update_order(
    db: Session, order_obj: models.Order, update_in: schemas.OrderUpdate
) -> models.Order:
    if update_in.item_name is not None:
        order_obj.item_name = update_in.item_name
    if update_in.quantity is not None:
        order_obj.quantity = update_in.quantity
    if update_in.price is not None:
        order_obj.price = update_in.price
    db.add(order_obj)
    db.commit()
    db.refresh(order_obj)
    return order_obj


def delete_order(db: Session, order_obj: models.Order) -> None:
    db.delete(order_obj)
    db.commit()
