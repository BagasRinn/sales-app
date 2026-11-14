"""Regression tests for wildcard-safe search filters.

Search input reaches PostgreSQL as a bind parameter, so these are not
SQL-injection tests. They guard the *other* problem: ``%`` and ``_`` are
wildcards in LIKE/ILIKE, so unescaped input like ``%`` matches every row and
forces a full table scan ("wildcard injection").

Covered:
- ``escape_like_literal`` / ``contains_pattern`` unit behaviour.
- End-to-end query behaviour on in-memory SQLite (no PostgreSQL/network),
  including SQL metacharacter payloads that must be treated as literals.
"""
import pytest
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.search import (
    LIKE_ESCAPE_CHAR,
    contains_pattern,
    escape_like_literal,
    ilike_contains,
)

Base = declarative_base()


class _Item(Base):
    __tablename__ = "search_items"
    id = Column(Integer, primary_key=True)
    name = Column(String(100))


@pytest.fixture()
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add_all(
        [
            _Item(id=1, name="Toko Sumber Rejeki"),
            _Item(id=2, name="Diskon 10%"),
            _Item(id=3, name="Diskon 10 Persen"),
            _Item(id=4, name="Toko_A"),
            _Item(id=5, name="TokoXA"),
            _Item(id=6, name="Back\\slash"),
        ]
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _names(session, value):
    query = session.query(_Item).filter(ilike_contains(_Item.name, value))
    return sorted(row.name for row in query.all())


class TestEscapeLikeLiteral:
    def test_percent_is_escaped(self):
        assert escape_like_literal("10%") == "10\\%"

    def test_underscore_is_escaped(self):
        assert escape_like_literal("toko_a") == "toko\\_a"

    def test_escape_character_is_escaped_first(self):
        assert escape_like_literal("a\\b") == "a\\\\b"

    def test_empty_and_none_return_empty_string(self):
        assert escape_like_literal("") == ""
        assert escape_like_literal(None) == ""

    def test_contains_pattern_wraps_escaped_value(self):
        assert contains_pattern("10%") == "%10\\%%"
        assert contains_pattern("") == "%%"


class TestLiteralSearch:
    def test_percent_matches_only_literal_percent(self, db):
        assert _names(db, "%") == ["Diskon 10%"]

    def test_underscore_matches_only_literal_underscore(self, db):
        assert _names(db, "_") == ["Toko_A"]

    def test_backslash_matches_only_literal_backslash(self, db):
        assert _names(db, "\\") == ["Back\\slash"]

    def test_normal_search_is_still_case_insensitive_contains(self, db):
        assert _names(db, "diskon") == ["Diskon 10 Persen", "Diskon 10%"]

    def test_sql_metacharacters_are_literal(self, db):
        assert _names(db, "' OR 1=1--") == []
        assert _names(db, "'); DROP TABLE search_items; --") == []
        # Table must still exist and be queryable.
        assert db.query(_Item).count() == 6

    def test_wildcard_payload_does_not_dump_every_row(self, db):
        assert len(_names(db, "%_%")) == 0
        assert db.query(_Item).count() == 6
