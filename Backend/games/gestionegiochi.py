from fastapi import APIRouter, HTTPException ,Query
from bson import ObjectId
from pymongo import MongoClient
from typing import List
from pydantic import BaseModel
from motor.motor_asyncio import AsyncIOMotorClient
import requests
from dotenv import load_dotenv
import os
load_dotenv()  # carica variabili da .env

MONGO_URI = os.getenv("MONGO_URI")


router = APIRouter()

# Mongo setup
client = MongoClient(MONGO_URI)
db = client["progetto_gaming"]
user_games_collection = db["user_games"]  # Nome corretto
games_collection = db["games"]
company_collection = db["company"]

# Helper per validare ObjectId
def is_valid_objectid(id: str) -> bool:
    try:
        ObjectId(id)
        return True
    except:
        return False

# --- Aggiungi Gioco a un Utente ---

client = MongoClient(MONGO_URI)
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
        game_doc = games_collection.find_one({"_id": game_id})

        if not game_doc:
            enriched_games.append({
                "game_id": game_id,
                "label": "Gioco non trovato",
                "logo image": None,
                "achievements": game_entry.get("achievements", [])
            })
            continue

        details = game_doc.get("details", {})
        logo_img = details.get("logo image") or details.get("logo")
        if not logo_img:
            logo_img = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png"

        # Obiettivi del gioco (lista ordinata, senza 'id')
        game_achievements_data = game_doc.get("obiettivi_steam", [])

        # Obiettivi dell'utente
        user_achievements = game_entry.get("achievements", [])
        enriched_achievements = []

        for i, ach in enumerate(user_achievements):
            # Prendi il relativo obiettivo del gioco (se esiste)
            game_ach = game_achievements_data[i] if i < len(game_achievements_data) else {}

            enriched_achievements.append({
                **ach,  # es. {'name': ..., 'achieved': ...}
                "description": game_ach.get("description", "N/A"),
                "icon": game_ach.get("icon"),
                "icongray": game_ach.get("icongray")
            })

        enriched_games.append({
            "game_id": game_id,
            "label": game_doc.get("label", "Senza nome"),
            "logo image": logo_img,
            "achievements": enriched_achievements,
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

@router.post("/fix_company_svg_redirects")
def fix_company_svg_redirects():
    updated = []
    for company in company_collection.find({}):
        logo_url = company.get("logo")

        if isinstance(logo_url, str) and logo_url.endswith(".svg") and "wikimedia" in logo_url:
            try:
                # Segui redirect
                response = requests.head(logo_url, allow_redirects=True, timeout=10)
                resolved_url = response.url

                # Se è cambiato, aggiorna
                if resolved_url != logo_url:
                    company_collection.update_one(
                        {"_id": company["_id"]},
                        {"$set": {"logo": resolved_url}}
                    )
                    updated.append({"_id": str(company["_id"]), "new_url": resolved_url})
            except Exception as e:
                print(f"Errore con company {company.get('_id')}: {e}")
                continue

    return {"updated_companies": updated}


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

@router.delete("/user/{user_id}/remove_game/{game_id}")
async def remove_game(user_id: str, game_id: str):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)

    result = user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$pull": {"games": {"game_id": game_id}}}  # game_id è una stringa (wikidata.id)
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Gioco non trovato per l'utente")

    return {"status": "Gioco rimosso con successo"}

@router.get("/company_logo")
def get_company_logo(name: str = Query(..., description="Nome dell'azienda (label o alias)")):
    company = company_collection.find_one({
        "$or": [
            {"label": {"$regex": f"^{name}$", "$options": "i"}},
            {"aliases": {"$regex": f"^{name}$", "$options": "i"}}
        ]
    })

    if not company:
        raise HTTPException(status_code=404, detail="Company not found")

    return {"label": company["label"], "logo": company.get("logo")}

@router.put("/user/{user_id}/game/{game_id}/achievement/{achievement_index}/toggle_achieved")
def toggle_achievement(user_id: str, game_id: str, achievement_index: int):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)

    # Trova il documento dell'utente
    user_doc = user_games_collection.find_one({"user_id": user_obj_id})
    if not user_doc:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    # Trova posizione del gioco
    games = user_doc.get("games", [])
    game_pos = next((i for i, g in enumerate(games) if g.get("game_id") == game_id), None)
    if game_pos is None:
        raise HTTPException(status_code=404, detail="Gioco non trovato per utente")

    # Trova achievement e controlla indice
    achievements = games[game_pos].get("achievements", [])
    if achievement_index < 0 or achievement_index >= len(achievements):
        raise HTTPException(status_code=404, detail="Achievement non trovato")

    # Prendi valore attuale e inverti
    current_value = achievements[achievement_index].get("achieved", False)
    new_value = not current_value

    # Campo dinamico da aggiornare
    update_field = f"games.{game_pos}.achievements.{achievement_index}.achieved"

    # Esegui update
    result = user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$set": {update_field: new_value}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Nessun aggiornamento effettuato")

    return {
        "message": f"Achievement {achievement_index} del gioco {game_id} aggiornato.",
        "new_achieved_value": new_value
    }
    

class GameListRequest(BaseModel):
    name: str
    game_ids: List[str]

@router.post("/user/{user_id}/create_list")
def create_game_list(user_id: str, request: GameListRequest):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")
    
    user_obj_id = ObjectId(user_id)

    # Verifica se l'utente esiste
    user_doc = user_games_collection.find_one({"user_id": user_obj_id})
    if not user_doc:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    # Aggiungi nuova lista
    new_list = {
        "name": request.name,
        "game_ids": request.game_ids
    }

    result = user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$push": {"lists": new_list}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=500, detail="Errore durante la creazione della lista")

    return {"message": f"Lista '{request.name}' creata con successo"}

@router.get("/user/{user_id}/lists")
def get_user_game_lists(user_id: str):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")
    
    user_obj_id = ObjectId(user_id)
    user_doc = user_games_collection.find_one({"user_id": user_obj_id})

    if not user_doc:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    lists = user_doc.get("lists", [])
    return {"lists": lists}

@router.post("/user/{user_id}/remove_game_from_all_lists/{game_id}")
def remove_game_from_all_lists(user_id: str, game_id: str):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)

    result = user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$pull": {"lists.$[].game_ids": game_id}}
    )

    if result.modified_count == 0:
        return {"message": "Il gioco non era presente in nessuna lista"}
    
    return {"message": "Gioco rimosso da tutte le liste"}

class AddGameToListRequest(BaseModel):
    name: str
    game_id: str

@router.post("/user/{user_id}/add_game_to_list")
def add_game_to_list(user_id: str, data: AddGameToListRequest):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)
    user_doc = user_games_collection.find_one({"user_id": user_obj_id})
    if not user_doc:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    lists = user_doc.get("lists", [])

    # Cerca la lista con il nome specificato
    for game_list in lists:
        if game_list["name"] == data.name:
            if data.game_id not in game_list["game_ids"]:
                game_list["game_ids"].append(data.game_id)
            break
    else:
        # Se non esiste, creala
        lists.append({
            "name": data.name,
            "game_ids": [data.game_id]
        })

    user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$set": {"lists": lists}}
    )

    return {"message": f"Gioco aggiunto alla lista '{data.name}'"}


@router.post("/user/{user_id}/remove_game_from_list")
def remove_game_from_list(user_id: str, list_name: str = Query(..., description="Nome della lista"), game_id: str = Query(..., description="ID del gioco da rimuovere")):
    if not is_valid_objectid(user_id):
        raise HTTPException(status_code=400, detail="User ID non valido")

    user_obj_id = ObjectId(user_id)
    user_doc = user_games_collection.find_one({"user_id": user_obj_id})

    if not user_doc:
        raise HTTPException(status_code=404, detail="Utente non trovato")

    lists = user_doc.get("lists", [])
    found_list = False
    for game_list in lists:
        if game_list["name"] == list_name:
            if game_id in game_list["game_ids"]:
                game_list["game_ids"].remove(game_id)
                found_list = True
                break
            else:
                raise HTTPException(status_code=404, detail="Gioco non trovato nella lista specificata")

    if not found_list:
        raise HTTPException(status_code=404, detail="Lista non trovata")

    user_games_collection.update_one(
        {"user_id": user_obj_id},
        {"$set": {"lists": lists}}
    )

    return {"message": f"Gioco rimosso dalla lista '{list_name}'"}
