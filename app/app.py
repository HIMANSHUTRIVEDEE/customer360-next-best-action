"""
Customer 360 — Next Best Action
Decision-support application for insurance service representatives.
Hackathon prototype — Streamlit-in-Snowflake (SiS).
"""

import streamlit as st

st.set_page_config(
    page_title="Customer 360 — Next Best Action",
    page_icon="🎯",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ---------------------------------------------------------------------------
# Shared session helpers — work in both SiS and local streamlit run
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Navigation — st.navigation (Streamlit 1.36+)
# ---------------------------------------------------------------------------

pg = st.navigation([
    st.Page("pages/00_Home.py", title="Home", icon="🏠", default=True),
    st.Page("pages/01_Customer360.py", title="Customer 360", icon="👤"),
    st.Page("pages/02_Risk_Signals.py", title="Risk Signals", icon="📊"),
    st.Page("pages/03_NBA_Recommendations.py", title="Recommendations", icon="🎯"),
])

pg.run()
