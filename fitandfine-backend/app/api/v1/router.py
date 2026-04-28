from fastapi import APIRouter

from app.api.v1 import auth, users, foods, logs, goals, weight, scan, ai

api_router = APIRouter()

api_router.include_router(auth.router,   prefix="/auth",   tags=["auth"])
api_router.include_router(users.router,  prefix="/users",  tags=["users"])
api_router.include_router(foods.router,  prefix="/foods",  tags=["foods"])
api_router.include_router(logs.router,   prefix="/logs",   tags=["logs"])
api_router.include_router(goals.router,  prefix="/goals",  tags=["goals"])
api_router.include_router(weight.router, prefix="/weight", tags=["weight"])
api_router.include_router(scan.router,   prefix="/scan",   tags=["scan"])
api_router.include_router(ai.router,     prefix="/ai",     tags=["ai"])
