import logging


def configure_logging(level: str = "INFO") -> None:
    """
    Konfiguriert den Root-Logger für journald-kompatible Ausgabe.

    journald fügt Timestamp und Service-Name selbst hinzu,
    daher enthält das Format nur Level, Logger-Name und Nachricht.
    """
    numeric = getattr(logging, level.upper(), logging.INFO)
    logging.basicConfig(
        level=numeric,
        format="%(levelname)-8s %(name)s: %(message)s",
    )
    # Gesprächige Bibliotheks-Logger auf WARNING begrenzen
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("multipart.multipart").setLevel(logging.WARNING)
