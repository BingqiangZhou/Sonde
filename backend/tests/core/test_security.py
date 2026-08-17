"""Tests for the security module — API key generation, Fernet encryption."""

from __future__ import annotations

import pytest

from app.core.security import decrypt_data, encrypt_data


class TestFernetEncryption:
    """Fernet symmetric encryption for AI API key storage."""

    def test_encrypt_decrypt_round_trip(self):
        plaintext = "sk-proj-abc123def456"
        encrypted = encrypt_data(plaintext)
        assert encrypted != plaintext
        assert decrypt_data(encrypted) == plaintext

    def test_encrypt_empty_string(self):
        assert encrypt_data("") == ""
        assert decrypt_data("") == ""

    def test_decrypt_invalid_ciphertext_raises(self):
        with pytest.raises(ValueError, match="Decryption failed"):
            decrypt_data("not-valid-fernet-ciphertext==")

    def test_different_plaintexts_produce_different_ciphertexts(self):
        enc1 = encrypt_data("key-one")
        enc2 = encrypt_data("key-two")
        assert enc1 != enc2

    def test_encrypts_unicode(self):
        plaintext = "api-key-with-\u00e9\u4e2d\u6587"
        assert decrypt_data(encrypt_data(plaintext)) == plaintext

    def test_encrypts_long_string(self):
        plaintext = "x" * 10000
        assert decrypt_data(encrypt_data(plaintext)) == plaintext
