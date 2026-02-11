from fastapi import FastAPI
from .config import get_settings
from .logging_config import setup_logging
from .routers import orders
from .db import engine
from .models import Base

settings = get_settings()

setup_logging(settings.LOG_LEVEL)
app = FastAPI(title=settings.APP_NAME)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(orders.router)
