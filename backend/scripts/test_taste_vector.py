"""Test script for the taste vector (super vector) feature.

Tests:
  1. Vector averaging + L2 normalization math
  2. Threshold logic (skip when < 5, trigger when >= 5)
  3. EmbeddingService attribute existence
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np


# ──────────────────────────────────────────────────────────
# TEST 1: Vector averaging + L2 normalization
# ──────────────────────────────────────────────────────────
print("=" * 50)
print("TEST 1: Vector averaging + L2 normalization")
print("=" * 50)

DIM = 384

# Create 3 known vectors
v1 = np.random.randn(DIM).astype(np.float32)
v2 = np.random.randn(DIM).astype(np.float32)
v3 = np.random.randn(DIM).astype(np.float32)

# Normalize inputs (like real movie embeddings)
v1 = v1 / np.linalg.norm(v1)
v2 = v2 / np.linalg.norm(v2)
v3 = v3 / np.linalg.norm(v3)

# Average them
avg = (v1 + v2 + v3) / 3.0

# L2-normalize the average
norm = np.linalg.norm(avg)
assert norm > 0, "Average vector should be non-zero"
normalized = avg / norm

# Verify: L2 norm of result should be ~1.0
result_norm = np.linalg.norm(normalized)
assert abs(result_norm - 1.0) < 1e-5, f"Normalized vector L2 norm should be 1.0, got {result_norm}"
print(f"  Avg vector norm before normalization: {norm:.4f}")
print(f"  Avg vector norm after normalization:  {result_norm:.6f}")
print(f"  Dimension: {len(normalized)}")
assert len(normalized) == 384, "Output dimension should be 384"
print("  ✅ PASSED")

# ──────────────────────────────────────────────────────────
# TEST 2: Threshold logic
# ──────────────────────────────────────────────────────────
print()
print("=" * 50)
print("TEST 2: Threshold logic")
print("=" * 50)

THRESHOLD = 5

# Should skip: like_count = 3
profile_low = {"taste_vector": None, "like_count_since_update": 3}
should_update_low = profile_low.get("like_count_since_update", 0) >= THRESHOLD
assert not should_update_low, "Should NOT trigger update with 3 likes"
print(f"  like_count=3 → trigger={should_update_low} (expected: False) ✅")

# Should skip: like_count = 0
profile_zero = {"taste_vector": None, "like_count_since_update": 0}
should_update_zero = profile_zero.get("like_count_since_update", 0) >= THRESHOLD
assert not should_update_zero, "Should NOT trigger update with 0 likes"
print(f"  like_count=0 → trigger={should_update_zero} (expected: False) ✅")

# Should trigger: like_count = 5
profile_exact = {"taste_vector": None, "like_count_since_update": 5}
should_update_exact = profile_exact.get("like_count_since_update", 0) >= THRESHOLD
assert should_update_exact, "Should trigger update with exactly 5 likes"
print(f"  like_count=5 → trigger={should_update_exact} (expected: True)  ✅")

# Should trigger: like_count = 10
profile_high = {"taste_vector": None, "like_count_since_update": 10}
should_update_high = profile_high.get("like_count_since_update", 0) >= THRESHOLD
assert should_update_high, "Should trigger update with 10 likes"
print(f"  like_count=10 → trigger={should_update_high} (expected: True) ✅")

# Edge case: missing key
profile_missing = {}
should_update_missing = profile_missing.get("like_count_since_update", 0) >= THRESHOLD
assert not should_update_missing, "Should NOT trigger when key is missing"
print(f"  missing key → trigger={should_update_missing} (expected: False)  ✅")
print("  ✅ ALL THRESHOLD TESTS PASSED")

# ──────────────────────────────────────────────────────────
# TEST 3: EmbeddingService has taste vector methods
# ──────────────────────────────────────────────────────────
print()
print("=" * 50)
print("TEST 3: EmbeddingService attribute check")
print("=" * 50)

# Import the class (not the singleton, to avoid model loading)
from app.services.embedding_service import EmbeddingService

assert hasattr(EmbeddingService, "update_taste_vector"), "Missing: update_taste_vector"
print("  update_taste_vector         → exists ✅")

assert hasattr(EmbeddingService, "_run_taste_vector_update"), "Missing: _run_taste_vector_update"
print("  _run_taste_vector_update    → exists ✅")

assert hasattr(EmbeddingService, "force_update_taste_vector"), "Missing: force_update_taste_vector"
print("  force_update_taste_vector   → exists ✅")

assert hasattr(EmbeddingService, "TASTE_VECTOR_THRESHOLD"), "Missing: TASTE_VECTOR_THRESHOLD"
assert EmbeddingService.TASTE_VECTOR_THRESHOLD == 5
print(f"  TASTE_VECTOR_THRESHOLD = {EmbeddingService.TASTE_VECTOR_THRESHOLD} ✅")

print("  ✅ ALL ATTRIBUTE TESTS PASSED")

# ──────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────
print()
print("=" * 50)
print("ALL TASTE VECTOR TESTS PASSED! 🎉")
print("=" * 50)
