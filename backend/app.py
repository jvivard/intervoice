from fastapi import FastAPI
from backend.api.routes import router
from fastapi.middleware.cors import CORSMiddleware
from backend.config import set_google_cloud_env_vars

# Load environment variables from .env file
set_google_cloud_env_vars()

app = FastAPI()
app.include_router(router)

origins = [
    "http://localhost:3000",            
    "http://localhost:8080",           
    "http://localhost:5000",            
    "http://localhost",                
    "https://aiview-fa69f.web.app",    # for production
    "https://aiview-fa69f.firebaseapp.com"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,            # or ["*"] to allow all
    allow_credentials=True,
    allow_methods=["*"],              # GET, POST, PUT, etc.
    allow_headers=["*"],              # Authorization, Content-Type, etc.
)
