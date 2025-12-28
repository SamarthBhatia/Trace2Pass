"""
Trace2Pass Reporter Module

Generates human-readable bug reports from diagnosis results.
Integrates with C-Reduce for test case minimization.
"""

from .report_generator import ReportGenerator
from .reducer import TestCaseReducer
from .templates import ReportTemplate, BugzillaTemplate, MarkdownTemplate
from .workarounds import WorkaroundGenerator

__all__ = [
    'ReportGenerator',
    'TestCaseReducer',
    'ReportTemplate',
    'BugzillaTemplate',
    'MarkdownTemplate',
    'WorkaroundGenerator'
]

__version__ = '0.1.0'
