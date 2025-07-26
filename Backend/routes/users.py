from fastapi import APIRouter , HTTPException

from models import User
import os
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId

MONGO_URI = os.getenv("MONGO_URI")
client = AsyncIOMotorClient(MONGO_URI)
db = client["progetto_gaming"]

# Definisci tutte le collections qui
users_collection = db["users"]

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/get-steamid")
async def get_steamid(email: str):
    user = await users_collection.find_one({"email": email}, {"_id": 0, "steam_id": 1})
    
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    
    if "steamid" in user:
        return {"steamid": user["steam_id"]}
    else:
        return {"message": "SteamID non presente per questo utente"}

@router.get("/get-nickname")
async def get_nickname(user_id: str):
    objid =ObjectId(user_id)
    user = await users_collection.find_one({"_id": objid}, {"_id": 0, "name": 1})
    
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    
    if "name" in user:
        print(user["name"])
        return {"name": user["name"]}
    else:
        print("b")
        return {"message": "Nickname non trovato per l'utente specificato"}