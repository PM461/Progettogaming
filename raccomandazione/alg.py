import json
import pandas as pd
from collections import defaultdict
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import normalize
import random

# === 1. Carica i file ===

with open('played.json', 'r', encoding='utf-8') as f:
    interazioni = json.load(f)

with open('games.json', 'r', encoding='utf-8') as f:
    giochi = json.load(f)

# === 2. Estrai (user_id, game_id) ===

interazioni_flat = []
for entry in interazioni:
    user_id = entry['user_id']['$oid']
    for gioco in entry.get('games', []):
        interazioni_flat.append((user_id, gioco['game_id']))

df = pd.DataFrame(interazioni_flat, columns=["user", "game"])

# Ottieni lista completa utenti (anche quelli senza giochi)
lista_utenti_completa = list(set(entry['user_id']['$oid'] for entry in interazioni))

# === 3. Costruisci matrice gioco × utente con conteggio ===

matrice = df.groupby(['game', 'user']).size().unstack(fill_value=0)

# === 4. Normalizza per gioco ===

matrice_norm = pd.DataFrame(
    normalize(matrice, axis=1),
    index=matrice.index,
    columns=matrice.columns
)

# === 5. Calcola similarità item-item ===

similarita = cosine_similarity(matrice_norm)
id_giochi = matrice.index.tolist()
df_similarita = pd.DataFrame(similarita, index=id_giochi, columns=id_giochi)

# === 5b. Content-based: Costruisci mappa generi e sviluppatori ===

def trova_campo(details, nomi_possibili):
    """Cerca un campo in details ignorando maiuscole/minuscole."""
    for k in details.keys():
        if k.lower() in nomi_possibili:
            return details[k]
    return None

mappa_genere = {}
mappa_sviluppatore = {}

for g in giochi:
    gid = g.get('_id')
    details = g.get('details', {})

    # === GENERE ===
    genere = trova_campo(details, ['genere', 'genre'])

    if gid and genere:
        if isinstance(genere, list):
            mappa_genere[gid] = ", ".join([gg.lower() for gg in genere])
        elif isinstance(genere, str):
            mappa_genere[gid] = genere.lower()

    # === SVILUPPATORE ===
    sviluppatore = trova_campo(details, ['developer', 'sviluppatore'])
    if gid and sviluppatore:
        if isinstance(sviluppatore, list):
            mappa_sviluppatore[gid] = sviluppatore[0].lower()
        elif isinstance(sviluppatore, str):
            mappa_sviluppatore[gid] = sviluppatore.lower()

# One-hot encoding generi
df_generi = pd.DataFrame.from_dict(mappa_genere, orient='index', columns=['genere'])
df_generi['genere'] = df_generi['genere'].fillna("sconosciuto")
df_generi_dummy = pd.get_dummies(df_generi['genere'])
df_generi_dummy.index.name = 'game_id'

# One-hot encoding sviluppatori
df_sviluppatori = pd.DataFrame.from_dict(mappa_sviluppatore, orient='index', columns=['sviluppatore'])
df_sviluppatori['sviluppatore'] = df_sviluppatori['sviluppatore'].fillna("sconosciuto")
df_sviluppatori_dummy = pd.get_dummies(df_sviluppatori['sviluppatore'])
df_sviluppatori_dummy.index.name = 'game_id'

# Combina generi e sviluppatori in unico DataFrame
df_contenuto = pd.concat([df_generi_dummy, df_sviluppatori_dummy], axis=1).fillna(0)


# === 6. Funzione di raccomandazione con smoothing ===

def raccomanda_giochi(user_id, top_n=40, soglia_similarita=0.1, epsilon=0.01):
    giocati = df[df['user'] == user_id]['game'].tolist()
    punteggi = defaultdict(float)
    raccomandazioni_finali = []

    if (user_id not in df['user'].values) or (len(giocati) == 0):
        # === Nuovo utente: suggerisci giochi più popolari tra tutti ===
        giochi_popolari = df['game'].value_counts()
        raccomandazioni_finali = giochi_popolari.head(top_n).index.tolist()

    else:
        # === Utente esistente: raccomandazioni collaborative ===
        for gioco in giocati:
            if gioco not in df_similarita.columns:
                continue
            simili = df_similarita[gioco].drop(labels=giocati, errors='ignore')
            for gioco_simile, score in simili.items():
                if score > 0:
                    punteggi[gioco_simile] += score
                else:
                    punteggi[gioco_simile] += epsilon

        # Aggiungi epsilon anche ai giochi mai visti (per non ignorarli)
        tutti_i_giochi = set(df_similarita.columns)
        mai_visti = tutti_i_giochi - set(giocati)
        for gioco_non_visto in mai_visti:
            if punteggi[gioco_non_visto] == 0:
                punteggi[gioco_non_visto] += epsilon

        raccomandati = sorted(punteggi.items(), key=lambda x: x[1], reverse=True)
        raccomandazioni_finali = [g[0] for g in raccomandati[:top_n]]

    # === Estensione per giochi mai giocati da nessuno (affini per contenuto) ===

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


# === 7. Recupera info sui giochi (robusto) ===

def descrizione_gioco(game_id):
    for g in giochi:
        if g.get('_id') == game_id:
            label = g.get('label', 'Nome sconosciuto')
            d = g.get('details', {})
            genere = None
            # Cerca genere ignorando case
            for k in d:
                if k.lower() in ['genere', 'genre']:
                    genere = d[k]
                    break
            if not genere:
                genere = 'Genere sconosciuto'

            if isinstance(genere, list):
                genere_str = ", ".join(genere)
            else:
                genere_str = str(genere)

            return f"{label} - {genere_str}"
    return game_id

# === 8. Esempio: raccomanda per un singolo utente ===

utente_test = "687e2b5bace1808bcc48d511"
risultato = raccomanda_giochi(utente_test , top_n=40)

print(f"\n🎯 Raccomandazioni per utente {utente_test}:")
for gid in risultato['raccomandati']:
    print(" -", descrizione_gioco(gid))

print("\n🧪 Giochi simili mai giocati da nessuno:")
for gid in risultato['nuovi_simili']:
    print(" -", descrizione_gioco(gid))


# === 9. Esporta raccomandazioni per tutti gli utenti ===

output = []

for uid in lista_utenti_completa:
    giochi_cons = raccomanda_giochi(uid, top_n=40)
    output.append({
        "user_id": uid,
        "recommendations": giochi_cons
    })

with open("raccomandazioni.json", "w", encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)
