# 🎮 GameHub — Ultimate Game Tracker & Community Platform

![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Steam](https://img.shields.io/badge/Steam-000000?style=for-the-badge&logo=steam&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-000000?style=for-the-badge&logo=JSON%20web%20tokens&logoColor=white)

**GameHub** è una piattaforma web e mobile multi-piattaforma progettata per tutti gli appassionati di videogiochi. Un vero e proprio punto di riferimento digitale in cui catalogare la propria collezione di titoli, tenere traccia dei progressi di gioco, recensire le proprie esperienze e condividere traguardi con i propri amici, supportato dall'integrazione con le principali API di gaming.

---

## 🌟 Caratteristiche Principali

### 📚 Enciclopedia & Catalogo Videoludico
* **Database completo ed in continua espansione**: Sincronizzazione automatica di schede gioco, generi, sviluppatori ed editori grazie a query SPARQL su **Wikidata**.
* **Schede Dettaglio**: Informazioni dettagliate su ogni titolo, specifiche, recensioni della community e lista degli obiettivi.

### 🏆 Tracking Libreria & Progressi
* **Gestione Libreria Personale**: Salva i tuoi giochi, organizzali in liste personalizzate e aggiorna lo stato di avanzamento (*In corso*, *Completato*, *Abbandonato*, *Wishlist*).
* **Tracciamento Statistiche**: Monitora il tempo di gioco (*playtime*) e gli obiettivi/trofei sbloccati (*achievements*).

### 🤝 Social & Community
* **Connetti con gli Amici**: Cerca utenti, invia richieste di amicizia e confronta la tua libreria e i tuoi progressi con quelli dei tuoi amici.
* **Recensioni e Votazioni**: Lascia la tua opinione sui titoli giocati e consulta le recensioni della community.
* **Controllo Privacy**: Gestisci le impostazioni di visibilità del tuo profilo (pubblico o privato).

### 🔑 Integrazione Multi-Piattaforma & OAuth
* **Steam OpenID & Web API**: Collega il tuo account Steam per importare automaticamente la libreria di giochi posseduti, le ore di gioco e i traguardi raggiunti.
* **Autenticazione Flessibile**: Accesso tramite email/password (con verifica via email) o Google OAuth.

### 🤖 Engine di Raccomandazione Personalizzato
* Sistema intelligente che analizza la tua storia di gioco e le tue preferenze per suggerirti i prossimi titoli da scoprire.

---

## 🛠️ Tech Stack & Badge

### **Backend**
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Python](https://img.shields.io/badge/Python_3.10+-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=flat-square&logo=mongodb&logoColor=white)](https://www.mongodb.com/)
[![JWT](https://img.shields.io/badge/JWT-JSON_Web_Tokens-000000?style=flat-square&logo=jsonwebtokens)](https://jwt.io/)
[![Steam API](https://img.shields.io/badge/Steam_Web_API-171a21?style=flat-square&logo=steam&logoColor=white)](https://partner.steamgames.com/)
[![Wikidata](https://img.shields.io/badge/Wikidata-SPARQL-006699?style=flat-square&logo=wikidata&logoColor=white)](https://www.wikidata.org/)

* **Framework**: Python 3.10+ / [FastAPI](https://fastapi.tiangolo.com/)
* **Database**: MongoDB
* **Autenticazione**: JWT (JSON Web Tokens), Passlib (Bcrypt), OAuth2 (Google & Steam)
* **Data Fetching**: SPARQL Wrapper (Wikidata), Steam Web API

### **Frontend**
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)

* **Framework**: [Flutter](https://flutter.dev/) (Dart)
* **Piattaforme Supportate**: Web, Android, iOS, Desktop

### **Modulo di Raccomandazione**
[![Python](https://img.shields.io/badge/Python-Algorithm-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)

* **Linguaggio**: Python
* **Elaborazione Dati**: JSON / Mongo Pipelines

---

## 🏗️ Architettura del Progetto

```
├── Backend/                 # Server API REST (FastAPI + MongoDB)
│   ├── auth/                # Gestione Login, Registrazione, Google OAuth e JWT
│   ├── games/               # Sincronizzazione Wikidata e Gestione Libreria
│   ├── routes/              # Social, Amicizie, Profilo Utente e Privacy
│   ├── Steam/               # Integrazione API ed OpenID di Steam
│   └── utils.py             # Utility e helper
│
├── Frontend/front_gaming/   # Applicazione Client Multi-piattaforma (Flutter / Dart)
│   ├── lib/
│   │   ├── schermate/       # Interfaccia Utente (Login, Libreria, Dettaglio Gioco, Profilo, Cerca)
│   │   ├── controllers/     # Gestione dello stato e logica applicativa
│   │   └── services/        # Client HTTP per comunicazione con il Backend
│
└── raccomandazione/         # Modulo IA / Algoritmo di Raccomandazione
    ├── alg.py               # Algoritmo di raccomandazione basato sul profilo utente
    └── import_in_mongo.py   # Script per popolamento delle raccomandazioni su MongoDB
```

---

## 🚀 Setup e Installazione

### Requisiti Preliminari

* **Python 3.10+**
* **Flutter SDK**
* **MongoDB** (istanza locale o MongoDB Atlas)
* **Chiavi API**: Steam Web API Key, Client ID Google OAuth

### 1. Backend (FastAPI)

1. Posizionati nella cartella Backend:
   ```bash
   cd Backend
   ```

2. Crea ed attiva un ambiente virtuale:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Installa le dipendenze:
   ```bash
   pip install -r requirements.txt
   ```

4. Configura le variabili d'ambiente creando un file `.env`:
   ```env
   MONGO_URI=mongodb://localhost:27017
   SECRET_KEY=la_tua_secret_key
   STEAM_API_KEY=la_tua_steam_api_key
   GOOGLE_CLIENT_ID=il_tuo_google_client_id
   ```

5. Avvia il server backend:
   ```bash
   uvicorn main:app --reload
   ```
   Il backend sarà disponibile su `http://localhost:8000` (Documentazione Swagger su `/docs`).

### 2. Modulo di Raccomandazione

1. Genera ed importa le raccomandazioni nel database:
   ```bash
   cd raccomandazione
   python alg.py
   python import_in_mongo.py
   ```

### 3. Frontend (Flutter)

1. Posizionati nella directory del frontend:
   ```bash
   cd Frontend/front_gaming
   ```

2. Ottieni le dipendenze di Flutter:
   ```bash
   flutter pub get
   ```

3. Avvia l'applicazione (es. su Web):
   ```bash
   flutter run -d chrome
   ```

---

## 📝 Licenza

Questo progetto è sviluppato a scopo didattico e dimostrativo.
