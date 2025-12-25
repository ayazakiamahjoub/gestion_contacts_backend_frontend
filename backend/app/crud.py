from sqlalchemy.orm import Session
from . import models, schemas, auth
from typing import List, Optional

# User CRUD
def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        hashed_password=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, email: str, password: str):
    user = get_user_by_email(db, email)
    if not user:
        return False
    if not auth.verify_password(password, user.hashed_password):
        return False
    return user

# Contact CRUD
def get_contacts(db: Session, user_id: int, skip: int = 0, limit: int = 100):
    return db.query(models.Contact)\
        .filter(models.Contact.user_id == user_id)\
        .offset(skip)\
        .limit(limit)\
        .all()

def get_contact(db: Session, contact_id: int, user_id: int):
    return db.query(models.Contact)\
        .filter(models.Contact.id == contact_id, models.Contact.user_id == user_id)\
        .first()

def create_contact(db: Session, contact: schemas.ContactCreate, user_id: int):
    db_contact = models.Contact(**contact.dict(), user_id=user_id)
    db.add(db_contact)
    db.commit()
    db.refresh(db_contact)
    return db_contact

def update_contact(db: Session, contact_id: int, contact: schemas.ContactUpdate, user_id: int):
    db_contact = get_contact(db, contact_id, user_id)
    if db_contact:
        for key, value in contact.dict(exclude_unset=True).items():
            setattr(db_contact, key, value)
        db.commit()
        db.refresh(db_contact)
    return db_contact

def delete_contact(db: Session, contact_id: int, user_id: int):
    db_contact = get_contact(db, contact_id, user_id)
    if db_contact:
        db.delete(db_contact)
        db.commit()
    return db_contact

def search_contacts(db: Session, user_id: int, query: str):
    return db.query(models.Contact)\
        .filter(
            models.Contact.user_id == user_id,
            (models.Contact.first_name.ilike(f"%{query}%")) |
            (models.Contact.last_name.ilike(f"%{query}%")) |
            (models.Contact.phone.ilike(f"%{query}%")) |
            (models.Contact.email.ilike(f"%{query}%"))
        )\
        .all()