import numpy as np

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    vec_a = np.asarray(a, dtype=np.float32).reshape(-1)
    vec_b = np.asarray(b, dtype=np.float32).reshape(-1)

    if vec_a.size == 0 or vec_b.size == 0:
        raise ValueError("Embedding vectors must not be empty.")

    if vec_a.shape != vec_b.shape:
        raise ValueError("Embedding vectors must have the same shape.")

    denom = float(np.linalg.norm(vec_a) * np.linalg.norm(vec_b))
    if denom <= 1e-12:
        return 0.0

    score = float(np.dot(vec_a, vec_b) / denom)
    return float(np.clip(score, -1.0, 1.0))
