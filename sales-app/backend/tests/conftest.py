"""Pytest configuration for branch isolation tests."""
import pytest


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "isolation: marks tests that verify per-branch data isolation",
    )
