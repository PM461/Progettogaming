from fastapi import APIRouter, Request, Query , HTTPException
from fastapi.responses import RedirectResponse, JSONResponse
from pymongo import MongoClient
from urllib.parse import urlencode
import re
from bson import ObjectId
import os
from dotenv import load_dotenv
import requests

load_dotenv()
STEAM_KEY = os.getenv("STEAM_KEY")
print("STEAM_KEY:", STEAM_KEY)


router = APIRouter()

# MongoDB Setup
client = MongoClient("mongodb://localhost:27017")
db = client["progetto_gaming"]
accounts_collection = db["accounts"]  # Sostituisci con il nome corretto della collezione utenti

# Steam OpenID config
STEAM_OPENID_URL = "https://steamcommunity.com/openid/login"
RETURN_TO = "http://localhost:8000/auth/steam/callback"  # Cambialo in produzione

def get_owned_games(steamid):
    url = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"
    params = {
        "key": STEAM_KEY,
        "steamid": steamid,
        "include_appinfo": True
    }
    response = requests.get(url, params=params)
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Errore nel recupero dei giochi")
    return response.json().get("response", {}).get("games", [])


def get_player_achievements(steamid, appid):
    url = "https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/"
    params = {
        "key": STEAM_KEY,
        "steamid": steamid,
        "appid": appid
    }
    response = requests.get(url, params=params)
    if response.status_code != 200:
        return None
    achievements = response.json().get("playerstats", {}).get("achievements", [])
    return {a["apiname"]: a["achieved"] for a in achievements if "apiname" in a}


@router.get("/auth/steam/login")
async def steam_login(account: str = Query(...)):
    """
    Inizia il login con Steam e passa l'ID dell'account al callback.
    """
    return_to_with_account = f"{RETURN_TO}?account={account}"

    params = {
        "openid.ns": "http://specs.openid.net/auth/2.0",
        "openid.mode": "checkid_setup",
        "openid.return_to": return_to_with_account,
        "openid.realm": "http://localhost:8000/",  # Cambia in produzione
        "openid.identity": "http://specs.openid.net/auth/2.0/identifier_select",
        "openid.claimed_id": "http://specs.openid.net/auth/2.0/identifier_select",
    }

    redirect_url = f"{STEAM_OPENID_URL}?{urlencode(params)}"
    return RedirectResponse(url=redirect_url)


@router.get("/auth/steam/callback")
async def steam_callback(request: Request, account: str):
    claimed_id = request.query_params.get("openid.claimed_id")
    if not claimed_id:
        return JSONResponse(status_code=400, content={"error": "Missing OpenID response"})

    match = re.search(r"https://steamcommunity.com/openid/id/(\d+)", claimed_id)
    if not match:
        return JSONResponse(status_code=400, content={"error": "Invalid SteamID format"})

    steamid = match.group(1)

    try:
        user = db.users.find_one({"_id": ObjectId(account)})
    except Exception:
        return JSONResponse(status_code=400, content={"error": "ID utente non valido"})

    if not user:
        return JSONResponse(status_code=404, content={"error": f"Account '{account}' non trovato nel DB"})

    db.users.update_one({"_id": ObjectId(account)}, {"$set": {"steam_id": steamid}})

    user_id = ObjectId(account)
    giochi_posseduti = get_owned_games(steamid)

    games_collection = db["games"]
    user_games_collection = db["user_games"]

    user_entry = user_games_collection.find_one({"user_id": user_id})
    if not user_entry:
        user_games_collection.insert_one({"user_id": user_id, "games": []})
        user_entry = user_games_collection.find_one({"user_id": user_id})  # 🔄 rileggi

    giochi_aggiunti = []

    for gioco in giochi_posseduti:
        appid = str(gioco["appid"])
        game_doc = games_collection.find_one({"details.identificativo Steam": appid})
        if not game_doc:
            continue

        game_id = game_doc["_id"]
        existing = next((g for g in user_entry["games"] if g["game_id"] == game_id), None)
        if existing:
            continue

        achievements = game_doc.get("obiettivi_steam", [])
        if not achievements:
            continue

        player_ach = get_player_achievements(steamid, int(appid)) or {}

        structured = []
        for a in achievements:
            api_name = a.get("name")
            if not api_name:
                continue
            structured.append({
                "name": a.get("displayName", ""),
                "apiname": api_name,
                "achieved": bool(player_ach.get(api_name, 0))
            })

        user_games_collection.update_one(
            {"user_id": user_id},
            {"$push": {
                "games": {
                    "game_id": game_id,
                    "achievements": structured
                }
            }}
        )

        giochi_aggiunti.append({
            "wikidata_id": game_doc.get("wikidata_id"),
            "nome": game_doc.get("title"),
            "steam_appid": appid,
            "achievements": structured
        })

    print("Player achievements for appid", appid)
    print(player_ach)

    return JSONResponse(content={
        "message": "Steam ID collegato e giochi sincronizzati con successo",
        "steamid": steamid,
        "giochi_aggiunti": giochi_aggiunti
    })
