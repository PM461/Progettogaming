from fastapi import APIRouter
from models import User

router = APIRouter(prefix="/users", tags=["Users"])

# esempio: registrazione utente
@router.post("/register")
async def register(user: User):
    # In una vera app, salveresti nel DB
    return {"msg": f"Utente {user.email} registrato!"}

# Simula login Google
@router.post("/google-login")
def google_login(user: User):
    # In un'app vera qui salveresti su MongoDB, per ora stampa a console
    print("Utente loggato con Google:", user.email)
    return {"message": "Login Google simulato", "user": user}