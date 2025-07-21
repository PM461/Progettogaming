from fastapi import APIRouter, Request, HTTPException, Depends
from authlib.integrations.starlette_client import OAuth, OAuthError
from starlette.responses import RedirectResponse
from pymongo import MongoClient
from jose import jwt
from datetime import datetime, timedelta
import os
import logging
from dotenv import load_dotenv

# Carica le variabili d'ambiente
load_dotenv()

# Configurazione del router
router = APIRouter(tags=["Authentication"])

# Configurazione MongoDB
client = MongoClient(os.getenv("MONGO_URI"))
db = client["progetto_gaming"]
users_collection = db["users"]

# Configurazione OAuth
oauth = OAuth()
oauth.register(
    name='google',
    client_id=os.getenv("GOOGLE_CLIENT_ID"),
    client_secret=os.getenv("GOOGLE_CLIENT_SECRET"),
    server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
    client_kwargs={'scope': 'openid email profile'},
)

# Configurazione JWT
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))

# Funzione per creare il token JWT
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

@router.get("/auth/google/login")
async def login(request: Request):
    try:
        redirect_uri = request.url_for('auth_callback')
        return await oauth.google.authorize_redirect(request, redirect_uri)
    except Exception as e:
        logging.error(f"Login error: {str(e)}")
        raise HTTPException(status_code=400, detail="Errore durante il login")

@router.get("/auth/google/callback")
async def auth_callback(request: Request):
    try:
        # 1. Ottieni il token
        token = await oauth.google.authorize_access_token(request)
        if not token:
            raise HTTPException(status_code=400, detail="Token mancante")
        
        # 2. Estrai user info
        user_info = token.get('userinfo')
        if not user_info:
            user_info = await oauth.google.userinfo(token=token)
        
        if not user_info.get('email'):
            raise HTTPException(status_code=400, detail="Email mancante")

        # 3. Prepara dati utente
        user_data = {
            "email": user_info["email"],
            "name": user_info["name"],
            "picture": user_info.get("picture"),
            "email_verified": user_info.get("email_verified", False)
        }

        # 4. Salva/aggiorna utente
        users_collection.update_one(
            {"email": user_data["email"]},
            {"$set": user_data},
            upsert=True
        )

        # 5. Genera il nostro JWT
        access_token = create_access_token({"sub": user_data["email"]})

        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": user_data
        }

    except OAuthError as e:
        logging.error(f"OAuth error: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Errore autenticazione: {str(e)}")
    except Exception as e:
        logging.error(f"Unexpected error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore interno: {str(e)}")