import json
import pandas as pd
import random
from collections import defaultdict
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import normalize
from pymongo import MongoClient

# === 1. Connessione MongoDB ===

client = MongoClient("mongodb+srv://paky:passwordsegreta@cluster0.oev2zfg.mongodb.net/progetto_gaming?retryWrites=true&w=majority")
db = client["progetto_gaming"]

games_collection = db["games"]
played_collection = db["user_games"]
raccomandati_collection = db["raccomandazioni"]

# === 2. Caricamento dati dal DB ===

giochi = list(games_collection.find())
interazioni = list(played_collection.find())

# === 3. Estrai (user_id, game_id) ===

interazioni_flat = []
for entry in interazioni:
    user_id = str(entry['user_id'])
    for gioco in entry.get('games', []):
        interazioni_flat.append((user_id, gioco['game_id']))

df = pd.DataFrame(interazioni_flat, columns=["user", "game"])

# Lista utenti
lista_utenti_completa = list(set(str(entry['user_id']) for entry in interazioni))

# === 4. Matrice gioco × utente ===

matrice = df.groupby(['game', 'user']).size().unstack(fill_value=0)

# === 5. Normalizza matrice per gioco ===
print("Contenuto di df:\n", df.head())
print("Shape matrice:", matrice.shape)

matrice_norm = pd.DataFrame(
    normalize(matrice, axis=1),
    index=matrice.index,
    columns=matrice.columns
)

# === 6. Similarità item-item ===

similarita = cosine_similarity(matrice_norm)
id_giochi = matrice.index.tolist()
df_similarita = pd.DataFrame(similarita, index=id_giochi, columns=id_giochi)

# === 7. Content-based: Generi e sviluppatori ===

def trova_campo(details, nomi_possibili):
    for k in details.keys():
        if k.lower() in nomi_possibili:
            return details[k]
    return None

mappa_genere = {}
mappa_sviluppatore = {}

for g in giochi:
    gid = g.get('_id')
    details = g.get('details', {})

    genere = trova_campo(details, ['genere', 'genre'])
    if gid and genere:
        if isinstance(genere, list):
            mappa_genere[gid] = ", ".join([gg.lower() for gg in genere])
        else:
            mappa_genere[gid] = genere.lower()

    sviluppatore = trova_campo(details, ['developer', 'sviluppatore'])
    if gid and sviluppatore:
        if isinstance(sviluppatore, list):
            mappa_sviluppatore[gid] = sviluppatore[0].lower()
        else:
            mappa_sviluppatore[gid] = sviluppatore.lower()

df_generi = pd.DataFrame.from_dict(mappa_genere, orient='index', columns=['genere']).fillna("sconosciuto")
df_generi_dummy = pd.get_dummies(df_generi['genere'])
df_generi_dummy.index.name = 'game_id'

df_sviluppatori = pd.DataFrame.from_dict(mappa_sviluppatore, orient='index', columns=['sviluppatore']).fillna("sconosciuto")
df_sviluppatori_dummy = pd.get_dummies(df_sviluppatori['sviluppatore'])
df_sviluppatori_dummy.index.name = 'game_id'

df_contenuto = pd.concat([df_generi_dummy, df_sviluppatori_dummy], axis=1).fillna(0)

# === 8. Funzione di raccomandazione ===

def raccomanda_giochi(user_id, top_n=40, soglia_similarita=0.1, epsilon=0.01):
    giocati = df[df['user'] == user_id]['game'].tolist()
    punteggi = defaultdict(float)
    raccomandazioni_finali = []

    if (user_id not in df['user'].values) or (len(giocati) == 0):
        giochi_popolari = df['game'].value_counts()
        raccomandazioni_finali = giochi_popolari.head(top_n).index.tolist()
    else:
        for gioco in giocati:
            if gioco not in df_similarita.columns:
                continue
            simili = df_similarita[gioco].drop(labels=giocati, errors='ignore')
            for gioco_simile, score in simili.items():
                if score > 0:
                    punteggi[gioco_simile] += score
                else:
                    punteggi[gioco_simile] += epsilon

        tutti_i_giochi = set(df_similarita.columns)
        mai_visti = tutti_i_giochi - set(giocati)
        for gioco_non_visto in mai_visti:
            if punteggi[gioco_non_visto] == 0:
                punteggi[gioco_non_visto] += epsilon

        raccomandati = sorted(punteggi.items(), key=lambda x: x[1], reverse=True)
        raccomandazioni_finali = [g[0] for g in raccomandati[:top_n]]

    # Content-based (affinità)
    tutti_i_giochi = set(g.get('_id') for g in giochi if g.get('_id'))
    giocati_da_chiunque = set(df['game'].unique())
    mai_giocati = tutti_i_giochi - giocati_da_chiunque

    generi_utente = set()
    dev_utente = set()

    for g in giochi:
        if g.get('_id') in giocati:
            d = g.get('details', {})
            genere = trova_campo(d, ['genere', 'genre'])
            dev = trova_campo(d, ['developer', 'sviluppatore'])

            if isinstance(genere, list):
                generi_utente.update([gg.lower() for gg in genere])
            elif isinstance(genere, str):
                generi_utente.add(genere.lower())

            if isinstance(dev, str):
                dev_utente.add(dev.lower())

    affini_ma_nuovi = []

    for g in giochi:
        gid = g.get('_id')
        if gid in mai_giocati:
            d = g.get('details', {})
            genere = trova_campo(d, ['genere', 'genre'])
            dev = trova_campo(d, ['developer', 'sviluppatore'])

            match_genere = False
            match_dev = False

            if isinstance(genere, list):
                match_genere = any(gg.lower() in generi_utente for gg in genere)
            elif isinstance(genere, str):
                match_genere = genere.lower() in generi_utente

            if isinstance(dev, str):
                match_dev = dev.lower() in dev_utente

            if match_genere or match_dev:
                affini_ma_nuovi.append(gid)

    random.shuffle(affini_ma_nuovi)

    return {
        "raccomandati": raccomandazioni_finali,
        "nuovi_simili": affini_ma_nuovi[:20]
    }

# === 9. Scrivi i risultati nella collection "raccomandati" ===

raccomandati_collection.delete_many({})  # Pulisce la collection

batch = []
for uid in lista_utenti_completa:
    consigli = raccomanda_giochi(uid, top_n=40)
    record = {
        "user_id": uid,
        "recommendations": {
            "raccomandati": consigli["raccomandati"],
            "nuovi_simili": consigli["nuovi_simili"]
        }
    }
    batch.append(record)

if batch:
    raccomandati_collection.insert_many(batch)

print(f"✅ Raccomandazioni generate per {len(batch)} utenti e salvate nella collection 'raccomandazioni'.")
