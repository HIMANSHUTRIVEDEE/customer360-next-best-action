"""Shared session helpers — importable by all pages."""

import streamlit as st


def _get_session():
    """Return a Snowpark session. Tries SiS first, then st.connection."""
    try:
        from snowflake.snowpark.context import get_active_session
        return get_active_session()
    except Exception:
        import os
        conn_name = os.getenv("SNOWFLAKE_DEFAULT_CONNECTION_NAME", "default")
        return st.connection("snowflake", connection_name=conn_name).session()


@st.cache_resource
def get_session():
    return _get_session()


def run_query(sql: str):
    """Execute SQL and return pandas DataFrame."""
    return get_session().sql(sql).to_pandas()


def execute_sql(sql: str):
    """Execute SQL without returning results."""
    get_session().sql(sql).collect()
