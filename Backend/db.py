from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")  # es: mongodb://localhost:27017
client = AsyncIOMotorClient(MONGO_URI)
db = client["progetto_gaming"]      # nome DB
users_collection = db["users"]      # tabella utenti
