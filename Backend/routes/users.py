from fastapi import APIRouter , HTTPException

from models import User
import os
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query
from bson import ObjectId
from db import db, users_collection
from utils import get_current_user
from pydantic import BaseModel

MONGO_URI = os.getenv("MONGO_URI")
client = AsyncIOMotorClient(MONGO_URI)
db = client["progetto_gaming"]
raccomandazioni_collection = db["raccomandazioni"]
games_collection =db["games"]
user_games_collection =db["user_games"]

# Definisci tutte le collections qui
users_collection = db["users"]

router = APIRouter(prefix="/users", tags=["Users"])

class PrivacyStatus(BaseModel):
    user_id: str
    is_private: bool

class PrivacyUpdate(BaseModel):
    is_private: bool

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

@router.get("/get-game-guide")
async def get_game_guide():
    raccomandazione = await user_games_collection.find_one({"_id": "game_guide"}, {"_id": 0})
    
    if not raccomandazione:
        raise HTTPException(status_code=404, detail="Game guide non trovata")
    
    return raccomandazione


from fastapi import Depends, Query
from db import users_collection

@router.get("/search")
async def search_users(q: str = Query(..., min_length=1)):
    rx = {"$regex": q, "$options": "i"}
    cursor = users_collection.find(
        {"$or": [{"name": rx}, {"nickname": rx}]},
        {"_id": 1, "name": 1, "nickname": 1, "picture": 1}
    ).limit(20)

    out = []
    async for u in cursor:
        out.append({
            "id": str(u["_id"]),
            "name": u.get("name"),
            "nickname": u.get("nickname"),
            "picture": u.get("picture"),
            #"email": u.get("email"),
        })
    return out

# routes/users.py (APPEND)

user_games = db["user_games"]
user_achievements = db["user_achievements"]

async def _get_oid(s: str) -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail="user id non valido")

async def _can_view_profile(target_id: ObjectId, current) -> None:
    """Se il profilo è privato e non sono io, lancia 403."""
    me = getattr(current, "id", None) or current.get("id")
    if me and ObjectId(me) == target_id:
        return
    user = await users_collection.find_one({"_id": target_id}, {"is_private": 1})
    is_private = bool(user.get("is_private")) if user else False
    if is_private:
        raise HTTPException(status_code=403, detail="Profilo privato")

@router.get("/me/privacy")
async def get_my_privacy(current=Depends(get_current_user)):
    me = ObjectId(current["id"])
    doc = await users_collection.find_one({"_id": me}, {"is_private": 1})
    return {"is_private": bool(doc.get("is_private", False))}

@router.patch("/me/privacy")
async def set_my_privacy(update: PrivacyUpdate, current=Depends(get_current_user)):
    me = ObjectId(current["id"])
    await users_collection.update_one(
        {"_id": me},
        {"$set": {"is_private": bool(update.is_private)}}
    )
    return {"is_private": bool(update.is_private)}

@router.get("/{user_id}/games")
async def get_user_games(
    user_id: str,
    limit: int = Query(50, ge=1, le=200),
    skip: int = Query(0, ge=0),
    current = Depends(get_current_user),
):
    uid = await _get_oid(user_id)
    await _can_view_profile(uid, current)
    cursor = user_games.find({"user_id": uid}).skip(skip).limit(limit)
    out = []
    async for g in cursor:
        out.append({
            "app_id": g.get("app_id"),
            "name": g.get("name"),
            "playtime": g.get("playtime", 0),
            "achievements_total": g.get("achievements_total", None),
            "achievements_completed": g.get("achievements_completed", None),
            "image": g.get("image"),  # opzionale
        })
    return out





@router.get("/{user_id}/privacy", response_model=PrivacyStatus)
async def read_user_privacy(user_id: str):
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="invalid user_id")
    doc = await users_collection.find_one({"_id": oid}, {"is_private": 1})
    if not doc:
        raise HTTPException(status_code=404, detail="user not found")
    return PrivacyStatus(user_id=str(oid), is_private=bool(doc.get("is_private", False)))


@router.get("/{user_id}/achievements")
async def get_user_achievements(
    user_id: str,
    completed: bool = Query(True),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    current = Depends(get_current_user),
):
    uid = await _get_oid(user_id)
    await _can_view_profile(uid, current)
    filt = {"user_id": uid}
    if completed is not None:
        filt["unlocked"] = bool(completed)
    cursor = user_achievements.find(filt).skip(skip).limit(limit)
    out = []
    async for a in cursor:
        out.append({
            "app_id": a.get("app_id"),
            "game": a.get("game"),
            "name": a.get("name"),
            "unlocked": bool(a.get("unlocked", False)),
            "unlocked_at": a.get("unlocked_at"),
            "icon": a.get("icon"),  # opzionale
        })
    return out
