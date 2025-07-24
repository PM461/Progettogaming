from pydantic import BaseModel, EmailStr

from pydantic import BaseModel, Field
import random

# Modello utente aggiornato in models.py
class User(BaseModel):
    email: str
    password: str | None = None  # Solo per login tradizionale
    name: str | None = None
    picture: str | None = None
    nickname: str | None = None
    user_code: str | None = None
    is_verified: bool = False
    verification_token: str | None = None
    #created_at: datetime = datetime.utcnow()
