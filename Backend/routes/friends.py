# Backend/routes/friends.py
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import Optional, Literal
from bson import ObjectId
from datetime import datetime

from db import db, users_collection
from utils import get_current_user  # usa il tuo auth esistente

router = APIRouter(prefix="/api/friends", tags=["friends"])
friends_collection = db["friendships"]

# ------------------ Helpers ------------------

def oid(s: str) -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail="ID non valido")

def pub_user(doc: dict) -> dict:
    if not doc:
        return {}
    # adatta i campi in base al tuo modello utenti (hai: email, name, picture, nickname, user_code)
    return {
        "id": str(doc.get("_id")),
        "name": doc.get("name") or doc.get("nickname") or (doc.get("email") or "").split("@")[0],
        "nickname": doc.get("nickname"),
        "picture": doc.get("picture"),
        #"email": doc.get("email"),
    }

async def get_me_id(current_user) -> ObjectId:
    """
    Il tuo get_current_user in genere ritorna uno username/email o un dict.
    Qui risolviamo sempre all'ObjectId dell'utente.
    """
    # 1) dict con _id/id/email
    if isinstance(current_user, dict):
        if current_user.get("id"):
            try:
                return ObjectId(current_user["id"])
            except Exception:
                pass
        if current_user.get("_id"):
            try:
                return ObjectId(current_user["_id"])
            except Exception:
                pass
        if current_user.get("email"):
            u = await users_collection.find_one({"email": current_user["email"]}, {"_id": 1})
            if u:
                return u["_id"]
    # 2) stringa: prova come email, poi come ObjectId
    if isinstance(current_user, str):
        u = await users_collection.find_one({"email": current_user}, {"_id": 1})
        if u:
            return u["_id"]
        try:
            return ObjectId(current_user)
        except Exception:
            pass
    raise HTTPException(status_code=401, detail="Impossibile determinare l'utente corrente")

async def ensure_user_exists(user_id: ObjectId):
    u = await users_collection.find_one({"_id": user_id}, {"_id": 1})
    if not u:
        raise HTTPException(status_code=404, detail="Utente target non trovato")

async def find_existing_relation(a: ObjectId, b: ObjectId) -> Optional[dict]:
    return await friends_collection.find_one({
        "$or": [
            {"requester_id": a, "recipient_id": b},
            {"requester_id": b, "recipient_id": a},
        ]
    })

# Indici consigliati (chiamati allo startup)
async def init_friend_indexes():
    await friends_collection.create_index([("requester_id", 1), ("recipient_id", 1)], unique=True)
    await friends_collection.create_index([("recipient_id", 1), ("status", 1)])
    await friends_collection.create_index([("requester_id", 1), ("status", 1)])

# ------------------ Schemi ------------------

class SendRequestBody(BaseModel):
    user_id: str = Field(..., description="ObjectId dell'utente da aggiungere")

class DecideBody(BaseModel):
    request_id: Optional[str] = None
    user_id: Optional[str] = None  # alternativa a request_id (ID del richiedente)

# ------------------ Rotte ------------------

@router.get("/list")
async def list_friends(current_user=Depends(get_current_user)):
    me = await get_me_id(current_user)
    cursor = friends_collection.find({
        "status": "accepted",
        "$or": [{"requester_id": me}, {"recipient_id": me}],
    })
    friends = []
    async for rel in cursor:
        other_id = rel["recipient_id"] if rel["requester_id"] == me else rel["requester_id"]
        other = await users_collection.find_one({"_id": other_id})
        friends.append({
            "friend": pub_user(other),
            "since": rel.get("created_at"),
        })
    return friends

@router.get("/requests")
async def pending_requests(current_user=Depends(get_current_user)):
    me = await get_me_id(current_user)
    # incoming: io sono recipient
    inc_cur = friends_collection.find({"status": "pending", "recipient_id": me})
    # outgoing: io sono requester
    out_cur = friends_collection.find({"status": "pending", "requester_id": me})

    incoming, outgoing = [], []
    async for r in inc_cur:
        req = await users_collection.find_one({"_id": r["requester_id"]})
        rec = await users_collection.find_one({"_id": r["recipient_id"]})
        incoming.append({
            "id": str(r["_id"]),
            "requester": pub_user(req),
            "recipient": pub_user(rec),
            "status": r["status"],
        })
    async for r in out_cur:
        req = await users_collection.find_one({"_id": r["requester_id"]})
        rec = await users_collection.find_one({"_id": r["recipient_id"]})
        outgoing.append({
            "id": str(r["_id"]),
            "requester": pub_user(req),
            "recipient": pub_user(rec),
            "status": r["status"],
        })
    return {"incoming": incoming, "outgoing": outgoing}

@router.post("/request", status_code=status.HTTP_201_CREATED)
async def send_request(body: SendRequestBody, current_user=Depends(get_current_user)):
    me = await get_me_id(current_user)
    target = oid(body.user_id)
    if me == target:
        raise HTTPException(400, detail="Non puoi aggiungere te stesso")
    await ensure_user_exists(target)

    existing = await find_existing_relation(me, target)
    if existing:
        st = existing["status"]
        # se l'altro mi aveva già invitato -> accetto
        if st == "pending" and existing["requester_id"] == target and existing["recipient_id"] == me:
            await friends_collection.update_one({"_id": existing["_id"]}, {"$set": {"status": "accepted", "updated_at": datetime.utcnow()}})
            return {"message": "Richiesta accettata automaticamente"}
        if st == "accepted":
            return {"message": "Siete già amici"}
        return {"message": "Richiesta già esistente"}

    doc = {
        "requester_id": me,
        "recipient_id": target,
        "status": "pending",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    res = await friends_collection.insert_one(doc)
    return {"id": str(res.inserted_id), "message": "Richiesta inviata"}

@router.post("/accept")
async def accept_request(body: DecideBody, current_user=Depends(get_current_user)):
    me = await get_me_id(current_user)
    q = {"status": "pending", "recipient_id": me}
    if body.request_id:
        q["_id"] = oid(body.request_id)
    elif body.user_id:
        q["requester_id"] = oid(body.user_id)
    else:
        raise HTTPException(400, detail="Fornisci request_id o user_id")

    upd = await friends_collection.find_one_and_update(
        q,
        {"$set": {"status": "accepted", "updated_at": datetime.utcnow()}},
        return_document=True
    )
    if not upd:
        raise HTTPException(404, detail="Richiesta non trovata")
    return {"message": "Amicizia confermata"}

@router.post("/reject")
async def reject_request(body: DecideBody, current_user=Depends(get_current_user)):
    me = await get_me_id(current_user)
    q = {"status": "pending", "recipient_id": me}
    if body.request_id:
        q["_id"] = oid(body.request_id)
    elif body.user_id:
        q["requester_id"] = oid(body.user_id)
    else:
        raise HTTPException(400, detail="Fornisci request_id o user_id")

    res = await friends_collection.delete_one(q)
    if res.deleted_count == 0:
        raise HTTPException(404, detail="Richiesta non trovata")
    return {"message": "Richiesta rifiutata"}

@router.delete("/{user_id}")
async def remove_friend(user_id: str, current_user=Depends(get_current_user)):
    me = await get_me_id(current_user)
    other = oid(user_id)
    q = {
        "status": "accepted",
        "$or": [
            {"requester_id": me, "recipient_id": other},
            {"requester_id": other, "recipient_id": me},
        ]
    }
    res = await friends_collection.delete_one(q)
    if res.deleted_count == 0:
        raise HTTPException(404, detail="Non siete (più) amici")
    return {"message": "Amico rimosso"}
