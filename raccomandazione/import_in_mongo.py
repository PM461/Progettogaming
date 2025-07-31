import json
from pymongo import MongoClient

# Connessione MongoDB
client = MongoClient('mongodb+srv://paky:passwordsegreta@cluster0.oev2zfg.mongodb.net/progetto_gaming?retryWrites=true&w=majority')  # Cambia URI se serve
db = client['progetto_gaming']
collezione = db['raccomandazioni']

# Carica dati dal file JSON
with open('raccomandazioni.json', 'r', encoding='utf-8') as f:
    dati = json.load(f)

# Inserisci i dati nella collezione
collezione.insert_many(dati)
print("Importazione completata!")
