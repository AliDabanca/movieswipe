"""
Generate TF-IDF embeddings for all movies and store in Supabase pgvector.

Usage:
    python scripts/generate_embeddings.py

Prerequisites:
    1. Run supabase_vector_migration.sql in Supabase SQL Editor
    2. pip install scikit-learn
"""

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.decomposition import TruncatedSVD
from app.data.datasources.supabase_datasource import SupabaseDataSource


EMBEDDING_DIM = 384  # Must match the vector(384) in SQL migration


def fetch_all_movies(ds: SupabaseDataSource):
    """Fetch all movies from Supabase."""
    response = ds.client.table("movies") \
        .select("id, name, genre, overview") \
        .order("id") \
        .execute()
    return response.data if response.data else []


def build_text_corpus(movies):
    """Build text corpus for TF-IDF from movie data.
    
    Combines: name + genre (repeated 3x for weight) + overview
    """
    texts = []
    for m in movies:
        name = m.get("name", "")
        genre = m.get("genre", "General")
        overview = m.get("overview", "") or ""
        
        # Genre is repeated to give it more weight in the vector
        text = f"{name} {genre} {genre} {genre} {overview}"
        texts.append(text)
    return texts


def generate_embeddings(texts, dim=EMBEDDING_DIM):
    """Generate fixed-dimension embeddings using TF-IDF + SVD dimensionality reduction.
    
    Pipeline:
        1. TF-IDF Vectorizer → sparse high-dimensional vectors
        2. TruncatedSVD → reduce to target dimension (384)
        3. L2 normalize → unit vectors for cosine similarity
    """
    print(f"  Building TF-IDF matrix from {len(texts)} documents...")
    
    vectorizer = TfidfVectorizer(
        max_features=5000,      # Vocabulary size cap
        stop_words="english",   # Remove common words
        ngram_range=(1, 2),     # Unigrams + bigrams
        min_df=2,               # Ignore very rare terms
        max_df=0.95,            # Ignore very common terms
    )
    
    tfidf_matrix = vectorizer.fit_transform(texts)
    print(f"  TF-IDF matrix shape: {tfidf_matrix.shape}")
    
    # Reduce dimensions to target
    actual_dim = min(dim, tfidf_matrix.shape[1] - 1, tfidf_matrix.shape[0] - 1)
    print(f"  Reducing to {actual_dim} dimensions via SVD...")
    
    svd = TruncatedSVD(n_components=actual_dim, random_state=42)
    reduced = svd.fit_transform(tfidf_matrix)
    
    explained_variance = svd.explained_variance_ratio_.sum()
    print(f"  Explained variance: {explained_variance:.1%}")
    
    # Pad to target dim if needed
    if actual_dim < dim:
        padding = np.zeros((reduced.shape[0], dim - actual_dim))
        reduced = np.hstack([reduced, padding])
    
    # L2 normalize for cosine similarity
    norms = np.linalg.norm(reduced, axis=1, keepdims=True)
    norms[norms == 0] = 1  # Avoid division by zero
    normalized = reduced / norms
    
    return normalized


def main():
    print("=" * 60)
    print("  EMBEDDING GENERATION")
    print("=" * 60)
    
    ds = SupabaseDataSource()
    
    # Step 1: Fetch movies
    print("\n1. Fetching movies from Supabase...")
    movies = fetch_all_movies(ds)
    print(f"   Found {len(movies)} movies")
    
    if len(movies) < 5:
        print("   ⚠️  Too few movies for meaningful embeddings. Run sync first.")
        return
    
    # Step 2: Build corpus
    print("\n2. Building text corpus...")
    texts = build_text_corpus(movies)
    
    # Step 3: Generate embeddings
    print("\n3. Generating embeddings...")
    embeddings = generate_embeddings(texts)
    print(f"   Generated {embeddings.shape[0]} embeddings of dimension {embeddings.shape[1]}")
    
    # Step 4: Upload to Supabase
    print("\n4. Uploading embeddings to Supabase...")
    success = 0
    failed = 0
    
    for i, movie in enumerate(movies):
        embedding_list = embeddings[i].tolist()
        if ds.update_movie_embedding(movie["id"], embedding_list):
            success += 1
        else:
            failed += 1
        
        if (i + 1) % 50 == 0:
            print(f"   Progress: {i+1}/{len(movies)} ({success} success, {failed} failed)")
    
    print(f"\n   ✅ Done: {success} embeddings uploaded, {failed} failed")
    
    # Step 5: Quick sanity check
    print("\n5. Sanity check — finding similar movies for first movie...")
    test_movie = movies[0]
    similar = ds.get_similar_movies(test_movie["id"], limit=3)
    print(f"   Source: {test_movie['name']} ({test_movie.get('genre', '?')})")
    for s in similar:
        sim_score = s.get("similarity", "?")
        print(f"   → {s['name']} ({s.get('genre', '?')}) - similarity: {sim_score}")
    
    print("\n" + "=" * 60)
    print("  EMBEDDING GENERATION COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()
