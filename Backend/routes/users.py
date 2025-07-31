from fastapi import APIRouter , HTTPException

from models import User
import os
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId


MONGO_URI = os.getenv("MONGO_URI")
client = AsyncIOMotorClient(MONGO_URI)
db = client["progetto_gaming"]
raccomandazioni_collection = db["raccomandazioni"]
games_collection =db["games"]

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
    
@router.get("/get-propic")
async def get_propic(user_id: str):
    try:
        objid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID utente non valido")

    user = await users_collection.find_one({"_id": objid}, {"_id": 0, "propic": 1})
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    
    if "propic" in user:
        return {"propic": user["propic"]}
    else:
        return {"message": "Propic non trovata"}

# ✅ Nuova rotta: Imposta la propic
@router.get("/set-propic")
async def set_propic(user_id: str, propic_url: str):
    try:
        objid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID utente non valido")

    result = await users_collection.update_one(
        {"_id": objid},
        {"$set": {"propic": propic_url}}
    )
    
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    return {"message": "Propic aggiornata con successo", "propic": propic_url}  

@router.get("/get-email")
async def get_email(user_id: str):
    try:
        objid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID utente non valido")

    user = await users_collection.find_one({"_id": objid}, {"_id": 0, "email": 1})
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    if "email" in user:
        return {"email": user["email"]}
    else:
        return {"message": "Email non trovata per l'utente specificato"}  
    
    
    
@router.get("/get-data")
async def get_data(user_id: str):
    try:
        objid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID utente non valido")

    user = await users_collection.find_one({"_id": objid}, {"_id": 0, "data": 1})
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    if "data" in user:
        return {"data": user["data"]}
    else:
        return {"message": "Data non trovata per l'utente specificato"}
    
@router.get("/get-raccomandazione")
async def get_raccomandazione(user_id: str):
    
    raccomandazione = await raccomandazioni_collection.find_one({"user_id": user_id})
    print(raccomandazione)
    if not raccomandazione:
        raise HTTPException(status_code=404, detail="Raccomandazione non trovata per l'utente specificato")
    
    # Converti ObjectId in stringa se presente nel documento
    raccomandazione["_id"] = str(raccomandazione["_id"])
    if "user_id" in raccomandazione:
        raccomandazione["user_id"] = str(raccomandazione["user_id"])

    return {"raccomandazione": raccomandazione}




@router.get("/get-raccomandazioni")
async def get_raccomandazioni(user_id: str):
    raccomandazione = await raccomandazioni_collection.find_one({"user_id": user_id})
    if not raccomandazione:
        raise HTTPException(status_code=404, detail="Raccomandazione non trovata per l'utente specificato")

    raccomandazione["_id"] = str(raccomandazione["_id"])
    if "user_id" in raccomandazione:
        raccomandazione["user_id"] = str(raccomandazione["user_id"])

    recommendations = raccomandazione.get("recommendations", {})
    detailed_recommendations = {}

    for list_name, game_ids in recommendations.items():
        # Evita problemi se per caso la lista non è una lista
        if not isinstance(game_ids, list):
            detailed_recommendations[list_name] = []
            continue

        # Recupera i dettagli dei giochi dal DB
        cursor = games_collection.find({"_id": {"$in": game_ids}})
        giochi_dettagliati = await cursor.to_list(length=None)

        # Converti ObjectId in stringa
        for game in giochi_dettagliati:
            if "_id" in game:
                # Nel tuo caso _id è una stringa (esempio Q1330234), ma se fosse ObjectId convertilo:
                if not isinstance(game["_id"], str):
                    game["_id"] = str(game["_id"])

        detailed_recommendations[list_name] = giochi_dettagliati

    raccomandazione["recommendations"] = detailed_recommendations

    return {"raccomandazione": raccomandazione}

