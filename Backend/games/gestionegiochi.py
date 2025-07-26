from fastapi import APIRouter, HTTPException
from bson import ObjectId
from pymongo import MongoClient
from typing import List
from pydantic import BaseModel
from motor.motor_asyncio import AsyncIOMotorClient
import requests


router = APIRouter()

# Mongo setup
client = MongoClient("mongodb://localhost:27017")
db = client["progetto_gaming"]
user_games_collection = db["user_games"]  # Nome corretto
games_collection = db["games"]

# Helper per validare ObjectId
def is_valid_objectid(id: str) -> bool:
    try:
        ObjectId(id)
        return True
    except:
        return False

# --- Aggiungi Gioco a un Utente ---
@router.post("/user/{user_id}/add_game/{game_id}")
async def add_game(user_id: str, game_id: str):
    try:
        user_obj_id = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="User ID non valido")

    # Cerca il gioco sia per _id che per wikidata.id
    
    game = games_collection.find_one({"_id": game_id})
  
    if not game:
        raise HTTPException(status_code=404, detail="Gioco non trovato nel DB")

    # Prendi gli obiettivi Steam se presenti
    steam_achievements = game.get("obiettivi_steam", [])
    structured_achievements = [
        {"name": ach.get("name"), "achieved": False} for ach in steam_achievements
    ]

    # Verifica se l'utente ha già il gioco
    user_entry = user_games_collection.find_one({"user_id": user_obj_id})
    if not user_entry:
        user_games_collection.insert_one({
            "user_id": user_obj_id,
            "games": [
                {
                    "game_id": game["_id"],
                    "achievements": structured_achievements
                }
            ]
        })
    else:
        for g in user_entry["games"]:
            if g["game_id"] == game["_id"]:
                raise HTTPException(status_code=409, detail="Gioco già presente per l’utente")

        user_games_collection.update_one(
            {"user_id": user_obj_id},
            {"$push": {
                "games": {
                    "game_id": game["_id"],
                    "achievements": structured_achievements
                }
            }}
        )

    return {"status": "Gioco aggiunto", "game_id": str(game["_id"])}

# --- Rimuovi Gioco da un Utente ---
@router.delete("/user/{user_id}/remove_game/{game_id}")
async def remove_game(user_id: str, game_id: str):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)

    # Cerca gioco per _id o per wikidata.id
    if is_valid_objectid(game_id):
        game = games_collection.find_one({"_id": ObjectId(game_id)})
    else:
        game = games_collection.find_one({"wikidata.id": game_id})

    if not game:
        raise HTTPException(status_code=404, detail="Gioco non trovato nel DB")

    result = user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$pull": {"games": {"game_id": game["_id"]}}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Gioco non associato all'utente")

    return {"status": "Gioco rimosso con successo"}

router = APIRouter()
client = MongoClient("mongodb://localhost:27017")
db = client["progetto_gaming"]
user_games_collection = db["user_games"]

class AchievementUpdateRequest(BaseModel):
    user_id: str
    game_id: str
    achievement_apiname: str

def update_achievement(user_id: str, game_id: str, achievement_apiname: str, achieved: bool):
    result = user_games_collection.update_one(
        {
            "user_id": ObjectId(user_id),
            "games.game_id": game_id,
            "games.achievements.apiname": achievement_apiname
        },
        {
            "$set": {
                "games.$[game].achievements.$[ach].achieved": achieved
            }
        },
        array_filters=[
            {"game.game_id": game_id},
            {"ach.apiname": achievement_apiname}
        ]
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Gioco o obiettivo non trovato per l'utente")

    return {"message": f"Achievement '{achievement_apiname}' aggiornato a {'completato' if achieved else 'non completato'}"}

@router.post("/achievement/set_true")
async def set_achievement_true(
    user_id: str,
    game_id: str,
    achievement_apiname: str
):
    return update_achievement(user_id, game_id, achievement_apiname, True)

@router.post("/achievement/set_false")
async def set_achievement_false(
    user_id: str,
    game_id: str,
    achievement_apiname: str
):
    return update_achievement(user_id, game_id, achievement_apiname, False)

@router.get("/find_game")
def find_game(query: str):
    cursor = games_collection.find(
        {"label": {"$regex": query, "$options": "i"}},
        {"_id": 0}
    )

    results = list(cursor)  # ✅ sincrono

    if not results:
        raise HTTPException(status_code=404, detail="Nessun gioco trovato")

    return {"results": results}


@router.get("/user/{user_id}/games")
async def get_user_games_with_labels_and_logo(user_id: str):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)
    user_entry = user_games_collection.find_one({"user_id": user_obj_id})

    if not user_entry or "games" not in user_entry:
        return {"games": []}

    enriched_games = []

    for game_entry in user_entry["games"]:
        game_id = game_entry["game_id"]

        # Cerchiamo il gioco nella collezione 'games'
        game_doc = games_collection.find_one({"_id": game_id})
        print("DEBUG logo_image:", game_doc.get("logo image"), type(game_doc.get("logo image")))

        if game_doc:
            details = game_doc.get("details", {})
            logo_img = details.get("logo image")
            if not logo_img:
                logo_img = details.get("logo")
            if not logo_img:
                logo_img = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png"


            enriched_games.append({
                "game_id": game_id,
                "label": game_doc.get("label", "Senza nome"),
                "logo image": logo_img,
                "achievements": game_entry.get("achievements", []),
                "editore": details.get("editore", "N/A"),
                "genere": details.get("genere", "N/A"),
                "sviluppatore": details.get("sviluppatore", "N/A"),
                "serie": details.get("serie", "N/A"),
                "piattaforma": details.get("piattaforma", []),
                "modalità di gioco": details.get("modalità di gioco", "N/A"),
                "dispositivo di ingresso": details.get("dispositivo di ingresso", "N/A"),
                "data di pubblicazione": details.get("data di pubblicazione", "N/A"),
                "distributore": details.get("distributore", []),
                "sito web ufficiale": details.get("sito web ufficiale", "N/A"),
                "classificazione USK": details.get("classificazione USK", "N/A"),
                "identificativo Steam": details.get("identificativo Steam", "N/A"),
                "identificativo GOG.com": details.get("identificativo GOG.com", "N/A"),
            })
        else:
            enriched_games.append({
                "game_id": game_id,
                "label": "Gioco non trovato",
                "logo image": None,
                "achievements": game_entry.get("achievements", []),
            })

    return {"games": enriched_games}

@router.post("/fix_svg_redirects")
def fix_svg_redirects():
    updated = []
    for game in games_collection.find({}):
        details = game.get("details", {})
        logo_field = details.get("logo image") or details.get("logo")

        if isinstance(logo_field, str) and logo_field.endswith(".svg") and "wikimedia" in logo_field:
            try:
                # Segui redirect
                response = requests.head(logo_field, allow_redirects=True, timeout=10)
                resolved_url = response.url

                # Se l'URL è diverso, aggiorna nel DB
                if resolved_url != logo_field:
                    # Aggiorna il campo corretto
                    if "logo image" in details:
                        games_collection.update_one(
                            {"_id": game["_id"]},
                            {"$set": {"details.logo image": resolved_url}}
                        )
                    elif "logo" in details:
                        games_collection.update_one(
                            {"_id": game["_id"]},
                            {"$set": {"details.logo": resolved_url}}
                        )
                    updated.append({"_id": str(game["_id"]), "new_url": resolved_url})
            except Exception as e:
                print(f"Errore con gioco {game.get('_id')}: {e}")
                continue

    return {"updated_games": updated}
