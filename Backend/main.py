from fastapi import FastAPI ,Depends
from utils import get_current_user
from auth.auth import router as auth_router 
from games import wikidata , gestionegiochi
from auth import google
from Steam import access
from fastapi.middleware.cors import CORSMiddleware
from routes import users
from starlette.middleware.sessions import SessionMiddleware
import os
import motor.motor_asyncio
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from starlette.middleware.sessions import SessionMiddleware
from dotenv import load_dotenv

load_dotenv()  # carica le variabili dal file .env

SECRET_KEY = os.getenv("JWT_SECRET_KEY")
ALGORITHM = os.getenv("JWT_ALGORITHM")


client = motor.motor_asyncio.AsyncIOMotorClient(os.getenv("MONGO_URI"))
try:
    client.admin.command('ping')
    print("✅ Connessione a MongoDB riuscita!")
except Exception as e:
    print(f"❌ Errore di connessione MongoDB: {e}")
    raise

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



app.include_router(wikidata.router, prefix="/api/wikidata", tags=["wikidata"])
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(google.router)
app.include_router(access.router)
app.include_router(gestionegiochi.router)
app.include_router(users.router, prefix="/api")
# middleware della sessione
secret_key = os.getenv("SESSION_SECRET_KEY")
if not secret_key:
    raise RuntimeError("SESSION_SECRET_KEY non impostato nel .env")

app.add_middleware(
    SessionMiddleware,
    secret_key=secret_key,
    session_cookie="session_cookie",
    same_site="lax",
    https_only=False  # Solo per sviluppo locale
)
@app.get("/protected")
async def protected_route(current_user: str = Depends(get_current_user)):
    return {"message": f"Ciao {current_user}, sei autenticato!"}

@app.get("/")
def home():
    return {"msg": "Backend attivo"}
