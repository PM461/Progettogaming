from fastapi import APIRouter, Request, Query , HTTPException
from fastapi.responses import RedirectResponse, JSONResponse
from pymongo import MongoClient
from urllib.parse import urlencode
import re
from fastapi.responses import HTMLResponse
import httpx
import time
from bson import ObjectId
import os
from dotenv import load_dotenv
import requests


load_dotenv()  # carica variabili da .env

MONGO_URI = os.getenv("MONGO_URI")
SERV = os.getenv("SERV")
STEAM_KEY = os.getenv("STEAM_KEY")
print("STEAM_KEY:", STEAM_KEY)


router = APIRouter()

# MongoDB Setup
client = MongoClient(MONGO_URI)
db = client["progetto_gaming"]
accounts_collection = db["accounts"] 
games_collection = db["games"]# Sostituisci con il nome corretto della collezione utenti

# Steam OpenID config
STEAM_OPENID_URL = "https://steamcommunity.com/openid/login"
RETURN_TO = SERV +"auth/steam/callback"  # Cambialo in produzione

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
        "openid.realm": SERV,  # Cambia in produzione
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

    # Pagina HTML che prova a chiudere la finestra
    html_content = f"""
    <html>
      <head>
        <title>Login completato</title>
      </head>
      <body>
        <script>
          window.close();
          // Se non funziona chiudi, fai redirect a uno schema custom per Flutter
          window.location.href = 'myapp://login-success?steamid={steamid}&account={account}';
        </script>
        <p>Login completato! Se la finestra non si chiude, chiudila manualmente.</p>
      </body>
    </html>
    """

    return HTMLResponse(content=html_content)
    

@router.get("/users/get-steamid")
async def get_steamid(user_id: str = Query(...)):
    try:
        user = db.users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise HTTPException(status_code=400, detail="ID utente non valido")

    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    steam_id = user.get("steam_id")
    if not steam_id:
        return {"steam_id": None, "message": "SteamID non presente"}

    return {"steam_id": steam_id}




def fetch_achievements(appid: int):
    url = "https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/"
    params = {"key": STEAM_KEY, "appid": appid}

    try:
        r = httpx.get(url, params=params, timeout=10)
        data = r.json()
        achievements = data.get("game", {}).get("availableGameStats", {}).get("achievements", [])
        return [
            {
                "name": a.get("displayName"),
                "description": a.get("description", ""),
                "icon": a.get("icon"),
            }
            for a in achievements
        ]
    except Exception as e:
        print(f"Errore achievements Steam per {appid}: {e}")
        return []


def fetch_reviews(appid: int):
    url = f"https://store.steampowered.com/appreviews/{appid}"
    params = {"json": 1, "language": "all"}

    try:
        r = httpx.get(url, params=params, timeout=10)
        data = r.json()
        summary = data.get("query_summary", {})
        total_reviews = summary.get("total_reviews", 0)
        rating_percent = summary.get("total_positive", 0) / total_reviews * 100 if total_reviews > 0 else 0
        stars = round((rating_percent / 100) * 5, 1)
        return {
            "total_reviews": total_reviews,
            "rating_percent": rating_percent,
            "stars": stars
        }
    except Exception as e:
        print(f"Errore reviews Steam per {appid}: {e}")
        return {"total_reviews": 0, "rating_percent": 0, "stars": 0}


# === ROUTE ===

@router.post("/update_steam_data")
def update_steam_data():
    cursor = games_collection.find({"details.identificativo Steam": {"$exists": True}})
    count = 0
    updated = 0

    for game in cursor:
        # Skip se già aggiornato
        if "steam" in game and "achievements" in game["steam"]:
            continue

        appid = game["details"]["identificativo Steam"]
        achievements = fetch_achievements(appid)
        reviews = fetch_reviews(appid)

        update_data = {
            "obiettivi_steam": achievements,
            "reviews": reviews
        }

        games_collection.update_one({"_id": game["_id"]}, {"$set": update_data})
        updated += 1
        count += 1

        # Rate limit: 3 giochi al secondo
        if count % 3 == 0:
            time.sleep(1)

    return {"status": "completato", "aggiornati": updated}




@router.post("/check_or_add_game")
def check_or_add_game(name: str = None, steam_appid: int = None):
    if not name and not steam_appid:
        raise HTTPException(status_code=400, detail="Devi fornire almeno il nome o lo steam_appid")

    # Cerca gioco per nome o per steam_appid
    query = []
    if name:
        query.append({"label": {"$regex": f"^{name}$", "$options": "i"}})
    if steam_appid:
        query.append({"_id": str(steam_appid)})  # Cerca per ID steam come _id

    existing_game = None
    if query:
        existing_game = games_collection.find_one({"$or": query})

    if existing_game:
        existing_game["_id"] = str(existing_game["_id"])
        return {"status": "exists", "game": existing_game}

    if not steam_appid:
        raise HTTPException(status_code=400, detail="Per aggiungere un gioco da Steam serve lo steam_appid")

    # Chiama Steam API
    url = f"https://store.steampowered.com/api/appdetails?appids={steam_appid}"
    try:
        response = requests.get(url, timeout=10)
        data = response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore chiamata Steam API: {e}")

    if not data or not data.get(str(steam_appid), {}).get("success", False):
        raise HTTPException(status_code=404, detail="Gioco non trovato su Steam")

    app_data = data[str(steam_appid)]["data"]

    game_doc = {
        "_id": str(steam_appid),  # Steam ID come _id (stringa)
        "label": app_data.get("name", "Senza nome"),
        "details": {
            "editore": app_data.get("publishers", []),
            "genere": [g["description"] for g in app_data.get("genres", [])],
            "sviluppatore": app_data.get("developers", []),
            "serie": app_data.get("series", "N/A") if "series" in app_data else "N/A",
            "piattaforma": [k for k, v in app_data.get("platforms", {}).items() if v],
            "modalità di gioco": ", ".join([c.get("description", "") for c in app_data.get("categories", [])]) if app_data.get("categories") else "N/A",
            "dispositivo di ingresso": "N/A",
            "data di pubblicazione": app_data.get("release_date", {}).get("date", "N/A"),
            "distributore": app_data.get("publishers", []),
            "sito web ufficiale": app_data.get("website", "N/A"),
            "classificazione USK": app_data.get("content_descriptions", {}).get("notes", "N/A"),
            "identificativo Steam": str(steam_appid),
            "identificativo GOG.com": "N/A",
            "logo image": app_data.get("header_image"),
        },
        "obiettivi_steam": []
    }

    # Inserisci nel DB
    try:
        games_collection.insert_one(game_doc)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore durante l'inserimento nel DB: {e}")

    return {"status": "added", "game": game_doc}


@router.post("/sync_steam_games")
def sync_steam_games(limit: int = 10, offset: int = 0):
    """
    Scarica giochi da Steam (tramite GetAppList), verifica se esistono nel DB.
    Se non esistono, li aggiunge mappando i campi correttamente.
    """
    steam_list_url = "https://api.steampowered.com/ISteamApps/GetAppList/v2/"
    try:
        response = requests.get(steam_list_url, timeout=10)
        all_apps = response.json().get("applist", {}).get("apps", [])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nella chiamata a Steam GetAppList: {e}")

    if not all_apps:
        raise HTTPException(status_code=500, detail="Nessun gioco ottenuto da Steam")

    selected_apps = all_apps[offset:offset + limit]
    added = []
    skipped = []

    for app in selected_apps:
        appid = app["appid"]
        name = app["name"]

        # Verifica se già nel DB
        exists = games_collection.find_one({
            "$or": [
                {"label": {"$regex": f"^{name}$", "$options": "i"}},
                {"details.identificativo Steam": str(appid)}
            ]
        })

        if exists:
            skipped.append({"appid": appid, "name": name})
            continue

        # Ottieni dettagli
        try:
            details_url = f"https://store.steampowered.com/api/appdetails?appids={appid}"
            details_response = requests.get(details_url, timeout=10)
            game_data = details_response.json()
            if not game_data or not game_data.get(str(appid), {}).get("success", False):
                skipped.append({"appid": appid, "name": name, "reason": "Dati non disponibili"})
                continue

            app_data = game_data[str(appid)]["data"]
        except Exception as e:
            skipped.append({"appid": appid, "name": name, "reason": f"Errore fetch: {e}"})
            continue

        # Mappatura ai tuoi campi
        game_doc = {
            "label": app_data.get("name", name),
            "details": {
                "editore": app_data.get("publishers", []),
                "genere": [g["description"] for g in app_data.get("genres", [])] if "genres" in app_data else [],
                "sviluppatore": app_data.get("developers", []),
                "serie": "N/A",
                "piattaforma": [k for k, v in app_data.get("platforms", {}).items() if v],
                "modalità di gioco": ", ".join([c.get("description", "") for c in app_data.get("categories", [])]) if "categories" in app_data else "N/A",
                "dispositivo di ingresso": "N/A",
                "data di pubblicazione": app_data.get("release_date", {}).get("date", "N/A"),
                "distributore": app_data.get("publishers", []),
                "sito web ufficiale": app_data.get("website", "N/A"),
                "classificazione USK": app_data.get("content_descriptions", {}).get("notes", "N/A"),
                "identificativo Steam": str(appid),
                "identificativo GOG.com": "N/A",
                "logo image": app_data.get("header_image"),
            },
            "obiettivi_steam": []  # Potresti estendere con Steam WebAPI
        }

        # Inserisci nel DB
        games_collection.insert_one(game_doc)
        added.append({"appid": appid, "name": app_data.get("name", name)})

    return {
        "added_count": len(added),
        "skipped_count": len(skipped),
        "added": added,
        "skipped": skipped
    }