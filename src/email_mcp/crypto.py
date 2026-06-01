"""Fernet-based encryption for stored credentials."""

import os
import base64
from pathlib import Path

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from .config import ENCRYPTION_KEY_PATH


def _ensure_key() -> bytes:
    """Load or generate the encryption key."""
    key_path = Path(ENCRYPTION_KEY_PATH)
    if key_path.exists():
        return key_path.read_bytes()
    key = Fernet.generate_key()
    key_path.parent.mkdir(parents=True, exist_ok=True)
    key_path.write_bytes(key)
    key_path.chmod(0o600)
    return key


_fernet: Fernet | None = None


def get_fernet() -> Fernet:
    global _fernet
    if _fernet is None:
        _fernet = Fernet(_ensure_key())
    return _fernet


def encrypt(plaintext: str) -> str:
    """Encrypt a string and return base64-encoded ciphertext."""
    return get_fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt(ciphertext: str) -> str:
    """Decrypt base64-encoded ciphertext back to plaintext."""
    return get_fernet().decrypt(ciphertext.encode("utf-8")).decode("utf-8")
