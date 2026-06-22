import os

# Muss vor jedem App-Import gesetzt sein, da get_settings() gecacht ist.
# Die Settings-Validierung läuft beim ersten Import von app.database.
os.environ.setdefault("SECRET_KEY", "test_secret_key_for_pytest_minimum_32_characters")
os.environ.setdefault("USER_PASSWORD_HASH", "test_hash")
os.environ.setdefault("ADMIN_PASSWORD_HASH", "test_hash")
