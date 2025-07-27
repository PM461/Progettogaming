from fastapi import APIRouter, HTTPException , Depends
from datetime import datetime, timedelta
import secrets
from datetime import datetime

import smtplib
from jose import JWTError, jwt
from pydantic import BaseModel
import os
from passlib.context import CryptContext
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv
# Aggiungi dopo le altre importazioni
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
router = APIRouter(tags=["Traditional Auth"])
def hash_password(password: str):
    return pwd_context.hash(password)
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")  
ALGORITHM = os.getenv("ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES =  int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))  # <-- fix qui
MONGO_URI = os.getenv("MONGO_URI")
client = AsyncIOMotorClient(MONGO_URI)
db = client["progetto_gaming"]

# Definisci tutte le collections qui
users_collection = db["users"]
# Configurazione Email (aggiungi a .env)
# EMAIL_SENDER=tuo@gmail.com
# EMAIL_PASSWORD=tua_password
# EMAIL_SERVER=smtp.gmail.com
# EMAIL_PORT=587

#to-do : configura un mail server
def send_verification_email(email: str, token: str):
    msg = MIMEText(f"Clicca per verificare il tuo account: http://tuosito.com/verify?token={token}")
    msg['Subject'] = "Verifica il tuo account"
    msg['From'] = os.getenv("EMAIL_SENDER")
    msg['To'] = email

    EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))  # Converti in intero
    with smtplib.SMTP(os.getenv("EMAIL_SERVER"), EMAIL_PORT) as server:
        server.starttls()
        server.login(os.getenv("EMAIL_SENDER"), os.getenv("EMAIL_PASSWORD"))
        server.send_message(msg)


@router.post("/register")
async def register(email: str, password: str, name: str ):
    if await users_collection.find_one({"email": email}):
        raise HTTPException(status_code=400, detail="Email già registrata")

    verification_token = secrets.token_urlsafe(32)
    user_data = {
        "email": email,
        "password": hash_password(password),
        "name": name,
        "propic":0,
        "data": datetime.now().strftime("%d/%m/%Y"), 
        "email_verified": False,
        "verification_token": verification_token
    }

    await users_collection.insert_one(user_data)
    send_verification_email(email, verification_token)

    return {"message": "Email di verifica inviata"}

def verify_password(plain_password: str, hashed_password: str):
    return pwd_context.verify(plain_password, hashed_password)

@router.get("/verify")
async def verify_email(token: str):
    user = await users_collection.find_one({"verification_token": token})
    if not user:
        raise HTTPException(status_code=404, detail="Token non valido")

    await users_collection.update_one(
        {"email": user["email"]},
        {"$set": {"is_verified": True, "verification_token": None}}
    )

    return {"message": "Account verificato con successo!"}

@router.post("/forgot-password")
async def forgot_password(email: str):
    user = users_collection.find_one({"email": email})
    if not user:
        return {"message": "Se l'email esiste, ti invieremo un link"}  # Privacy
    
    reset_token = secrets.token_urlsafe(32)
    users_collection.update_one(
        {"email": email},
        {"$set": {"reset_token": reset_token}}
    )
    
    send_password_reset_email(email, reset_token)
    return {"message": "Email di reset inviata"}

def send_password_reset_email(email: str, token: str):
    msg = MIMEText(f"Resetta la tua password: http://tuosito.com/reset-password?token={token}")
    msg['Subject'] = "Reset Password"
    msg['From'] = os.getenv("EMAIL_SENDER")
    msg['To'] = email

    EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))  # assicurati che sia un intero
    with smtplib.SMTP(os.getenv("EMAIL_SERVER"), EMAIL_PORT) as server:
        server.starttls()
        server.login(os.getenv("EMAIL_SENDER"), os.getenv("EMAIL_PASSWORD"))
        server.send_message(msg)
        
class DeleteAccountRequest(BaseModel):
    email: str
    password: str

@router.delete("/delete-account")
async def delete_account(email: str  , password : str):
    user = await users_collection.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    if not verify_password(password, user["password"]):
        raise HTTPException(status_code=401, detail="Password errata")

    await users_collection.delete_one({"email": email})
    return {"message": "Account eliminato con successo"}

class LoginRequest(BaseModel):
    email: str
    password: str

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

@router.post("/login")
async def login_json(data: LoginRequest):
    user = await users_collection.find_one({"email": data.email})
    if not user or not verify_password(data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Credenziali non valide")

    if not user.get("email_verified", False):
        raise HTTPException(status_code=403, detail="Email non verificata")

    access_token = create_access_token(data={"sub": user["email"]})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": str(user["_id"])  
    }