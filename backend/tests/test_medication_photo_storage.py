"""Unit tests for medication photo encrypted storage helpers."""

from pathlib import Path

import pytest

from medication_photo_storage import (
    _UPLOAD_ROOT,
    delete_medication_photo,
    load_medication_photo,
    save_medication_photo,
)


def test_save_and_load_round_trip():
    rel = save_medication_photo(
        profile_id=99,
        medication_id=1,
        image_bytes=b"jpeg-payload",
        mime_type="image/jpeg",
    )
    image_bytes, mime = load_medication_photo(rel)
    assert image_bytes == b"jpeg-payload"
    assert mime == "image/jpeg"
    delete_medication_photo(rel)


@pytest.mark.parametrize(
    "bad_path",
    [
        "../../../etc/passwd",
        "uploads/medication_photos/../../config.py",
        "/etc/passwd",
    ],
)
def test_load_rejects_path_traversal(bad_path):
    with pytest.raises(ValueError, match="Invalid medication photo path"):
        load_medication_photo(bad_path)


def test_delete_ignores_path_traversal():
    delete_medication_photo("uploads/medication_photos/../../config.py")


def test_load_missing_file_raises():
    with pytest.raises(FileNotFoundError):
        load_medication_photo("uploads/medication_photos/99999/missing.enc")


def test_saved_file_lives_under_upload_root():
    rel = save_medication_photo(
        profile_id=77,
        medication_id=2,
        image_bytes=b"x",
        mime_type="image/png",
    )
    absolute = (Path(__file__).resolve().parent.parent / rel).resolve()
    assert str(absolute).startswith(str(_UPLOAD_ROOT.resolve()))
    delete_medication_photo(rel)
