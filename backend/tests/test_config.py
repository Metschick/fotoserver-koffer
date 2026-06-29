"""
Tests für die Sicherheits-Validatoren in app/config.py.

Stellt sicher, dass unsichere Konfigurationen frühzeitig abgefangen werden
und nicht still in den Betrieb gelangen.
"""

import pytest
from pydantic import ValidationError

from app.config import Settings
from tests.constants import TEST_SECRET_KEY

# ── secret_key-Validator ───────────────────────────────────────────────────

def test_secret_key_change_me_raises():
    with pytest.raises(ValidationError, match="secret_key"):
        Settings(secret_key="CHANGE_ME")


def test_secret_key_too_short_raises():
    with pytest.raises(ValidationError, match="secret_key"):
        Settings(secret_key="short")


def test_secret_key_exactly_32_chars_accepted():
    key = "a" * 32
    s = Settings(secret_key=key)
    assert s.secret_key == key


def test_secret_key_longer_than_32_chars_accepted():
    key = "x" * 64
    s = Settings(secret_key=key)
    assert s.secret_key == key


# ── log_level-Validator ────────────────────────────────────────────────────

@pytest.mark.parametrize("level", ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"])
def test_log_level_valid_values_accepted(level):
    s = Settings(secret_key=TEST_SECRET_KEY, log_level=level)
    assert s.log_level == level


def test_log_level_normalized_to_uppercase():
    s = Settings(secret_key=TEST_SECRET_KEY, log_level="info")
    assert s.log_level == "INFO"


def test_log_level_invalid_value_raises():
    with pytest.raises(ValidationError, match="log_level"):
        Settings(secret_key=TEST_SECRET_KEY, log_level="VERBOSE")


def test_log_level_empty_string_raises():
    with pytest.raises(ValidationError, match="log_level"):
        Settings(secret_key=TEST_SECRET_KEY, log_level="")
