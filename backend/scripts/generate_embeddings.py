"""
[LEGACY — DEPRECATED] Generate TF-IDF embeddings for movies.

⚠️  This script has been superseded by:
    app/services/embedding_service.py (Sentence-Transformers, all-MiniLM-L6-v2)

Kept for reference only. Use the new system instead:
    - Sync auto-generates embeddings for new movies.
    - POST /movies/sync/backfill-embeddings fills missing ones.

Original usage:
    python scripts/generate_embeddings.py
"""

print("⚠️  DEPRECATED: This script is no longer needed.")
print("   Embeddings are now auto-generated during TMDB sync.")
print("   To backfill missing embeddings, use:")
print("   POST /movies/sync/backfill-embeddings")
print()
print("   Or run directly:")
print("   python -c \"from app.services.embedding_service import embedding_service; embedding_service.backfill_embeddings()\"")
