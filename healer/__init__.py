"""
Trace2Pass Healer - Automated compiler bug healing.

Consumes diagnosis results and applies targeted fixes to produce correct binaries
without human intervention. Three strategies available:
  1. FunctionOptNone - Disable optimization for the buggy function
  2. PassBypass - Remove the culprit pass from the optimization pipeline
  3. CompilerBarrier - Insert optimization barriers at affected locations
"""

from .healer import Healer, HealingRecipe, HealingResult
from .recipe_cache import RecipeCache
from .strategies import (
    HealingStrategy,
    FunctionOptNoneStrategy,
    PassBypassStrategy,
    CompilerBarrierStrategy,
)

__all__ = [
    "Healer",
    "HealingRecipe",
    "HealingResult",
    "RecipeCache",
    "HealingStrategy",
    "FunctionOptNoneStrategy",
    "PassBypassStrategy",
    "CompilerBarrierStrategy",
]
