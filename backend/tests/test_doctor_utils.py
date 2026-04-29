"""Tests for doctor_utils.py — doctor code generation helpers."""
from unittest.mock import MagicMock

import pytest

from doctor_utils import _doctor_code_candidate, ensure_unique_doctor_code


class TestDoctorCodeCandidate:
    """Test _doctor_code_candidate function."""

    def test_long_name_uses_first_three_letters(self):
        """Should use first 3 letters for names with 3+ letters."""
        code = _doctor_code_candidate("Rajesh Kumar")
        assert code.startswith("DRRAJ")
        assert len(code) == 7  # DR + 3 letters + 2 digits
        assert code[:2] == "DR"
        assert code[2:5].isalpha()
        assert code[5:7].isdigit()

    def test_short_name_pads_with_x(self):
        """Should pad with X for names with fewer than 3 letters."""
        code = _doctor_code_candidate("Al")
        assert code.startswith("DRALX")
        assert len(code) == 7

    def test_single_letter_name(self):
        """Should pad with XX for single letter names."""
        code = _doctor_code_candidate("Z")
        assert code.startswith("DRZXX")
        assert len(code) == 7

    def test_name_with_numbers_and_special_chars(self):
        """Should strip non-alphabetic characters."""
        code = _doctor_code_candidate("Dr. Smith123")
        # Should extract: DRS (from DrSmith)
        assert code.startswith("DRDRS") or code.startswith("DRSMI")
        assert len(code) == 7

    def test_empty_name(self):
        """Should handle empty name with XXX padding."""
        code = _doctor_code_candidate("")
        assert code.startswith("DRXXX")
        assert len(code) == 7

    def test_unicode_name(self):
        """Should handle unicode names (isalpha works for unicode)."""
        code = _doctor_code_candidate("José García")
        assert code.startswith("DR")
        assert len(code) == 7

    def test_generates_different_codes(self):
        """Should generate different codes due to random digits."""
        codes = {_doctor_code_candidate("Test User") for _ in range(20)}
        # With 2 random digits, we should see some variation
        assert len(codes) > 1


class TestEnsureUniqueDoctorCode:
    """Test ensure_unique_doctor_code function."""

    def test_returns_unique_code_first_try(self):
        """Should return code when no collision exists."""
        mock_db = MagicMock()
        mock_db.query.return_value.filter.return_value.first.return_value = None

        code = ensure_unique_doctor_code(mock_db, "Test Doctor")

        assert code.startswith("DR")
        assert len(code) == 7
        # Verify DB was queried
        mock_db.query.assert_called()

    def test_retries_on_collision(self):
        """Should retry when collision detected."""
        mock_db = MagicMock()

        # First call returns existing code (collision), second returns None
        mock_db.query.return_value.filter.return_value.first.side_effect = [
            MagicMock(),  # Collision
            None,  # Unique code found
        ]

        code = ensure_unique_doctor_code(mock_db, "Test Doctor")

        assert code.startswith("DR")
        # Should have been called at least twice
        assert mock_db.query.call_count >= 2

    def test_falls_back_to_random_suffix_after_20_collisions(self):
        """Should use random 5-char suffix after 20 name-based collisions."""
        mock_db = MagicMock()

        # First 20 calls return collision, then unique
        call_count = [0]

        def mock_first():
            call_count[0] += 1
            if call_count[0] <= 20:
                return MagicMock()  # Collision
            return None  # Unique

        mock_db.query.return_value.filter.return_value.first.side_effect = mock_first

        code = ensure_unique_doctor_code(mock_db, "Test Doctor")

        assert code.startswith("DR")
        assert len(code) == 7  # DR + 5 random chars
        # Should have tried 21 times (20 name-based + 1 random)
        assert call_count[0] == 21

    def test_raises_runtime_error_after_all_attempts_fail(self):
        """Should raise RuntimeError after 30 total collisions."""
        mock_db = MagicMock()

        # Always return collision
        mock_db.query.return_value.filter.return_value.first.return_value = MagicMock()

        with pytest.raises(RuntimeError, match="Unable to generate unique doctor code"):
            ensure_unique_doctor_code(mock_db, "Test Doctor")

        # Should have tried 30 times (20 name-based + 10 random)
        assert mock_db.query.call_count == 30

    def test_code_format_name_based(self):
        """Should return properly formatted name-based code."""
        mock_db = MagicMock()
        mock_db.query.return_value.filter.return_value.first.return_value = None

        code = ensure_unique_doctor_code(mock_db, "Alexander")

        assert code[:2] == "DR"
        assert code[2:5] == "ALE"
        assert code[5:7].isdigit()
        assert len(code) == 7

    def test_code_format_random_suffix(self):
        """Should return properly formatted random suffix code."""
        mock_db = MagicMock()

        # Force fallback to random suffix
        call_count = [0]

        def mock_first():
            call_count[0] += 1
            if call_count[0] <= 20:
                return MagicMock()
            return None

        mock_db.query.return_value.filter.return_value.first.side_effect = mock_first

        code = ensure_unique_doctor_code(mock_db, "Test Doctor")

        assert code[:2] == "DR"
        assert len(code) == 7
        # Random suffix can be letters or digits
        assert code[2:7].isalnum()
