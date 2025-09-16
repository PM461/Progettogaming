import os
import re
from typing import Optional

from fastapi import Depends, HTTPException, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from bson import ObjectId

from db import users_collection  # <-- importa la tua collezione utenti

# ===== Config =====
security = HTTPBearer(auto_error=False)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# In DEV lasciamo attivo l'uso di Bearer <ObjectIdUtente>.
# In PROD imposta ALLOW_OBJECTID_TOKEN=false per disattivarlo.
ALLOW_OBJECTID_TOKEN = os.getenv("ALLOW_OBJECTID_TOKEN", "true").lower() == "true"


# ===== Helpers Password =====
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ===== Token "di comodo" per DEV (NON sicuro per prod) =====
def create_dev_token(user_id: str) -> str:
    """
    In sviluppo puoi usare direttamente l'ObjectId come 'token':
    Authorization: Bearer <user_id>
    """
    if not re.fullmatch(r"[0-9a-fA-F]{24}", user_id):
        raise ValueError("user_id deve essere un ObjectId (24 hex)")
    return user_id


# ===== Auth principale (senza JWT) =====
async def get_current_user(
    x_user_id: Optional[str] = Header(default=None, alias="X-USER-ID")
):
    """
    Se è presente l'header X-USER-ID, ritorna un dict con l'id utente.
    Altrimenti 401. Questo sostituisce la vecchia logica JWT per l'ambiente attuale.
    """
    if not x_user_id:
        raise HTTPException(status_code=401, detail="not authenticated")
    # opzionale: validazioni base qui (es. formato ObjectId), altrimenti lascia così
    return {"id": x_user_id}
