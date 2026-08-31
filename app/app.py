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

pg = st.navigation([
    st.Page("pages/00_Home.py", title="Home", icon="🏠", default=True),
    st.Page("pages/01_Customer360.py", title="Customer 360", icon="👤"),
    st.Page("pages/02_Risk_Signals.py", title="Risk Signals", icon="📊"),
    st.Page("pages/03_NBA_Recommendations.py", title="Recommendations", icon="🎯"),
])

pg.run()
