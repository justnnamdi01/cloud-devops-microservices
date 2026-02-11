import logging
from logging.config import dictConfig


def setup_logging(level: str | None = None) -> None:
    level = (level or "INFO").upper()
    config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "default": {
                "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            }
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "default",
                "level": level,
            }
        },
        "root": {"handlers": ["console"], "level": level},
    }
    dictConfig(config)
    logging.getLogger("uvicorn").handlers = config["handlers"]
