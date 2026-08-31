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


@st.cache_data(ttl=300)
def run_query(sql: str):
    """Execute SQL and return pandas DataFrame. Cached for 5 minutes."""
    return get_session().sql(sql).to_pandas()


def execute_sql(sql: str):
    """Execute SQL without returning results (not cached)."""
    get_session().sql(sql).collect()


@st.cache_data(ttl=600)
def get_customer_options():
    """Return list of 'Name (ID)' strings for the customer selectbox. Cached for 10 minutes."""
    df = get_session().sql("""
        SELECT customer_id, first_name || ' ' || last_name AS customer_name
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
        ORDER BY last_name, first_name
    """).to_pandas()
    return df.apply(lambda r: f"{r['CUSTOMER_NAME']} ({r['CUSTOMER_ID']})", axis=1).tolist()


def parse_customer_selection(selection: str) -> str:
    """Extract customer_id from a 'Name (CUST-XXX)' selection string."""
    if "(" in selection and selection.endswith(")"):
        return selection.rsplit("(", 1)[1].rstrip(")")
    return selection
