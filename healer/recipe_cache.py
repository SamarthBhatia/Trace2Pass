"""
Persistent JSON cache for healing recipes.

Cache structure:
    {recipe_dir}/
        index.json          - Maps (source_hash, opt_level) -> recipe_id
        {recipe_id}.json    - Individual recipe files

Keyed by SHA256(source_content + opt_level) so source changes auto-invalidate.
"""

import hashlib
import json
import os
from typing import Optional, Dict, List


class RecipeCache:
    """Persistent cache for verified healing recipes."""

    def __init__(self, cache_dir: str = ".trace2pass/recipes"):
        self.cache_dir = os.path.abspath(cache_dir)
        self._index_path = os.path.join(self.cache_dir, "index.json")
        self._index: Dict[str, str] = {}  # cache_key -> recipe_id
        self._ensure_dir()
        self._load_index()

    def _ensure_dir(self):
        os.makedirs(self.cache_dir, exist_ok=True)

    def _load_index(self):
        if os.path.exists(self._index_path):
            with open(self._index_path, "r") as f:
                self._index = json.load(f)

    def _save_index(self):
        with open(self._index_path, "w") as f:
            json.dump(self._index, f, indent=2)

    @staticmethod
    def compute_cache_key(source_file: str, optimization_level: str) -> str:
        """Compute cache key from source content and optimization level."""
        with open(source_file, "rb") as f:
            content = f.read()
        combined = content + optimization_level.encode("utf-8")
        return hashlib.sha256(combined).hexdigest()

    @staticmethod
    def compute_recipe_id(source_hash: str, culprit_pass: str,
                          optimization_level: str) -> str:
        """Compute recipe ID from diagnosis parameters."""
        combined = f"{source_hash}:{culprit_pass}:{optimization_level}"
        return hashlib.sha256(combined.encode("utf-8")).hexdigest()[:16]

    def get(self, source_file: str, optimization_level: str) -> Optional[dict]:
        """
        Look up a cached recipe for the given source file and opt level.

        Returns recipe dict if found and source hasn't changed, else None.
        """
        cache_key = self.compute_cache_key(source_file, optimization_level)
        recipe_id = self._index.get(cache_key)
        if not recipe_id:
            return None

        recipe_path = os.path.join(self.cache_dir, f"{recipe_id}.json")
        if not os.path.exists(recipe_path):
            # Stale index entry
            del self._index[cache_key]
            self._save_index()
            return None

        with open(recipe_path, "r") as f:
            return json.load(f)

    def put(self, recipe: dict):
        """
        Store a verified recipe in the cache.

        The recipe dict must contain: recipe_id, source_file, source_hash,
        optimization_level.
        """
        recipe_id = recipe["recipe_id"]
        source_hash = recipe["source_hash"]
        opt_level = recipe["optimization_level"]

        # Compute cache key from current source content
        cache_key = self.compute_cache_key(
            recipe["source_file"], opt_level
        )

        # Write recipe file
        recipe_path = os.path.join(self.cache_dir, f"{recipe_id}.json")
        with open(recipe_path, "w") as f:
            json.dump(recipe, f, indent=2)

        # Update index
        self._index[cache_key] = recipe_id
        self._save_index()

    def invalidate(self, source_file: str, optimization_level: str) -> bool:
        """
        Remove cached recipe for the given source file and opt level.

        Returns True if a recipe was removed, False if none existed.
        """
        cache_key = self.compute_cache_key(source_file, optimization_level)
        recipe_id = self._index.pop(cache_key, None)
        if not recipe_id:
            return False

        recipe_path = os.path.join(self.cache_dir, f"{recipe_id}.json")
        if os.path.exists(recipe_path):
            os.remove(recipe_path)

        self._save_index()
        return True

    def list_all(self) -> List[dict]:
        """List all cached recipes."""
        recipes = []
        for cache_key, recipe_id in self._index.items():
            recipe_path = os.path.join(self.cache_dir, f"{recipe_id}.json")
            if os.path.exists(recipe_path):
                with open(recipe_path, "r") as f:
                    recipes.append(json.load(f))
        return recipes
