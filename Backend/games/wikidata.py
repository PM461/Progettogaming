from fastapi import APIRouter
from pymongo import MongoClient
from SPARQLWrapper import SPARQLWrapper, JSON
from datetime import datetime
import asyncio

router = APIRouter()

# Mongo setup
client = MongoClient("mongodb://localhost:27017")
db = client["progetto_gaming"]
collection = db["games"]

# SPARQL endpoint
ENDPOINT = "https://query.wikidata.org/sparql"

def get_sparql_wrapper():
    sparql = SPARQLWrapper(ENDPOINT)
    sparql.setReturnFormat(JSON)
    sparql.addCustomHttpHeader("User-Agent", "WikidataSyncBot/1.0 (your_email@example.com)")
    return sparql

def build_game_list_query(limit=50, offset=0):
    return f"""
    SELECT DISTINCT ?videogioco ?videogiocoLabel WHERE {{
      ?videogioco wdt:P31 wd:Q7889 .
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }}
    }}
    LIMIT {limit}
    OFFSET {offset}
    """

def build_game_detail_query(game_id):
    return f"""
    SELECT ?property ?propertyLabel ?value ?valueLabel WHERE {{
      wd:{game_id} ?p ?value .
      ?property wikibase:directClaim ?p .
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en,it". }}
    }}
    """

# Dizionario proprietà da filtrare (URI -> nome)
FILTER_PROPERTIES = {
    "http://www.wikidata.org/entity/P123": "editore",
    "http://www.wikidata.org/entity/P136": "genere",
    "http://www.wikidata.org/entity/P154": "logo",
    "http://www.wikidata.org/entity/P178": "sviluppatore",
    "http://www.wikidata.org/entity/P179": "serie",
    "http://www.wikidata.org/entity/P348": "identificatore di versione del software",
    "http://www.wikidata.org/entity/P400": "piattaforma",
    "http://www.wikidata.org/entity/P404": "modalità di gioco",
    "http://www.wikidata.org/entity/P479": "dispositivo di ingresso",
    "http://www.wikidata.org/entity/P577": "data di pubblicazione",
    "http://www.wikidata.org/entity/P750": "distributore",
    "http://www.wikidata.org/entity/P856": "sito web ufficiale",
    "http://www.wikidata.org/entity/P908": "classificazione PEGI",
    "http://www.wikidata.org/entity/P914": "classificazione USK",
    "http://www.wikidata.org/entity/P1476": "titolo",
    "http://www.wikidata.org/entity/P1733": "identificativo Steam",
    "http://www.wikidata.org/entity/P1873": "numero massimo di giocatori",
    "http://www.wikidata.org/entity/P2725": "identificativo GOG.com",
    "http://www.wikidata.org/entity/P2864": "OpenCritic ID",
    "http://www.wikidata.org/entity/P5885": "identificativo Microsoft Store product",
    "http://www.wikidata.org/entity/P6197": "identificativo Badgames",
    "http://www.wikidata.org/entity/P6278": "Epic Games Store ID",
    "http://www.wikidata.org/entity/P8084": "identificativo Nintendo eShop",
    "http://www.wikidata.org/entity/P8261": "identificativo Origin",
    "http://www.wikidata.org/entity/P12054": "identificativo Metacritic di un videogioco",
    "http://www.wikidata.org/entity/P12332": "PlayStation Store concept ID",
    "http://www.wikidata.org/entity/P12418": "Nintendo eShop (Europe) ID",
}

def fetch_games_batch(limit, offset):
    sparql = get_sparql_wrapper()
    sparql.setQuery(build_game_list_query(limit, offset))
    results = sparql.query().convert()
    return results["results"]["bindings"]

def fetch_game_details(game_id):
    sparql = get_sparql_wrapper()
    sparql.setQuery(build_game_detail_query(game_id))
    results = sparql.query().convert()
    filtered_data = {}

    for res in results["results"]["bindings"]:
        prop_uri = res["property"]["value"]
        if prop_uri in FILTER_PROPERTIES:
            key = FILTER_PROPERTIES[prop_uri]
            val = res.get("valueLabel", {}).get("value") or res.get("value", {}).get("value")
            
            # Se la proprietà è già presente, crea lista
            if key in filtered_data:
                if isinstance(filtered_data[key], list):
                    filtered_data[key].append(val)
                else:
                    filtered_data[key] = [filtered_data[key], val]
            else:
                filtered_data[key] = val
    return filtered_data

@router.post("/sync-games")
async def sync_games(batch_size: int = 50, max_batches: int = 10, delay: float = 1.5):
    total_inserted = 0
    for batch_num in range(max_batches):
        offset = batch_num * batch_size
        print(f"Fetching batch {batch_num + 1} (offset {offset})")

        try:
            batch = fetch_games_batch(batch_size, offset)
        except Exception as e:
            return {"error": f"Failed fetching game list: {e}"}

        if not batch:
            break

        for game in batch:
            wikidata_url = game["videogioco"]["value"]
            game_id = wikidata_url.split("/")[-1]
            label = game["videogiocoLabel"]["value"]

            if collection.find_one({"_id": game_id}):
                continue  # già sincronizzato

            try:
                details = fetch_game_details(game_id)
            except Exception as e:
                print(f"Error fetching details for {game_id}: {e}")
                continue

            doc = {
                "_id": game_id,
                "label": label,
                "details": details,  # solo proprietà filtrate qui
                "synced_at": datetime.utcnow()
            }

            collection.insert_one(doc)
            total_inserted += 1
            await asyncio.sleep(delay)

    return {"status": "sync complete", "inserted": total_inserted}
