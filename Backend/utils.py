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
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_user_id: Optional[str] = Header(default=None),  # fallback opzionale dev
):
    """
    Accetta:
      - Authorization: Bearer <ObjectIdUtente>
      - (opzionale, DEV) X-USER-ID: <ObjectIdUtente>

    Restituisce dict con {"id": "<_id utente>"} se tutto ok.
    """

    # Nessuna credenziale -> 401
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="not authenticated")

    token = (credentials.credentials or "").strip()

    # Caso principale DEV: token è un ObjectId valido
    if ALLOW_OBJECTID_TOKEN and re.fullmatch(r"[0-9a-fA-F]{24}", token):
        user = await users_collection.find_one({"_id": ObjectId(token)}, {"_id": 1})
        if user:
            return {"id": str(user["_id"])}
        # token formalmente valido ma utente non esistente
        raise HTTPException(status_code=401, detail="user not found")

    # Fallback opzionale: header X-USER-ID (utile se stai testando da browser senza header Bearer)
    if ALLOW_OBJECTID_TOKEN and x_user_id and re.fullmatch(r"[0-9a-fA-F]{24}", x_user_id):
        user = await users_collection.find_one({"_id": ObjectId(x_user_id)}, {"_id": 1})
        if user:
            return {"id": str(user["_id"])}

    # Altrimenti rifiuta
    raise HTTPException(status_code=401, detail="invalid token")
