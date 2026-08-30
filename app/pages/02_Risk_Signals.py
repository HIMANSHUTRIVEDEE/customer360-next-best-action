"""
Page 2: Risk Signals
Named, weighted, directional risk signals with evidence text.
"""

import streamlit as st

st.set_page_config(page_title="Risk Signals", page_icon="📊", layout="wide")


def _get_session():
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
    return get_session().sql(sql).to_pandas()


# ---------------------------------------------------------------------------
# Customer guard
# ---------------------------------------------------------------------------

customer_id = st.session_state.get("selected_customer_id")
if not customer_id:
    st.info("Select a customer from the home page first.")
    st.stop()

safe_id = customer_id.replace("'", "''")

# ---------------------------------------------------------------------------
# Load data
# ---------------------------------------------------------------------------

df_summary = run_query(f"""
    SELECT * FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_RISK_SUMMARY
    WHERE customer_id = '{safe_id}'
""")

df_signals = run_query(f"""
    SELECT signal_type, signal_value, signal_score, signal_weight,
           weighted_score, signal_direction, evidence_text
    FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_RISK_SIGNALS
    WHERE customer_id = '{safe_id}'
    ORDER BY weighted_score DESC
""")

df_customer = run_query(f"""
    SELECT first_name, last_name, risk_tier, composite_risk_score, risk_direction
    FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
    WHERE customer_id = '{safe_id}'
""")

if df_customer.empty:
    st.error(f"Customer `{customer_id}` not found.")
    st.stop()

cust = df_customer.iloc[0]
st.title(f"Risk Signals — {cust['FIRST_NAME']} {cust['LAST_NAME']}")

# ---------------------------------------------------------------------------
# Risk summary header
# ---------------------------------------------------------------------------

tier = str(cust["RISK_TIER"]).lower()
tier_colors = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}
tier_icon = tier_colors.get(tier, "⚪")

r1, r2, r3, r4 = st.columns(4)
r1.metric("Risk Tier", f"{tier_icon} {tier.upper()}")
r2.metric("Composite Score", f"{cust['COMPOSITE_RISK_SCORE']:.3f}")
r3.metric("Direction", str(cust["RISK_DIRECTION"]).title())

if not df_summary.empty:
    s = df_summary.iloc[0]
    r4.metric(
        "Signals",
        f"{int(s.get('WORSENING_SIGNALS', 0))} worsening / {int(s.get('IMPROVING_SIGNALS', 0))} improving",
    )

st.markdown("---")

# ---------------------------------------------------------------------------
# Signal bars — visual risk breakdown
# ---------------------------------------------------------------------------

st.subheader("Contributing Signals")

if df_signals.empty:
    st.info("No risk signals computed for this customer.")
    st.stop()

# Signal display names
signal_labels = {
    "renewal_proximity": "Renewal Proximity",
    "sentiment_negative": "Negative Sentiment",
    "sentiment_trend": "Sentiment Trend",
    "payment_risk": "Payment Risk",
    "complaint_activity": "Complaint Activity",
    "claim_activity": "Claim Activity",
    "engagement_drop": "Engagement Change",
    "cross_sell_opportunity": "Cross-Sell Opportunity",
}

direction_icons = {"worsening": "📉", "improving": "📈", "stable": "➡️"}

for _, sig in df_signals.iterrows():
    sig_type = str(sig["SIGNAL_TYPE"])
    label = signal_labels.get(sig_type, sig_type)
    score = float(sig["SIGNAL_SCORE"])
    weight = float(sig["SIGNAL_WEIGHT"])
    weighted = float(sig["WEIGHTED_SCORE"])
    direction = str(sig["SIGNAL_DIRECTION"]).lower()
    evidence = str(sig["EVIDENCE_TEXT"])
    dir_icon = direction_icons.get(direction, "")

    # Skip zero-weight signals with zero score (informational only, no contribution)
    is_informational = weight == 0

    col_label, col_bar, col_score = st.columns([2, 4, 1])

    with col_label:
        if is_informational:
            st.markdown(f"**{label}** ℹ️")
        else:
            st.markdown(f"**{label}** {dir_icon}")

    with col_bar:
        # Visual bar using Streamlit progress
        st.progress(min(score, 1.0))

    with col_score:
        if is_informational:
            st.markdown(f"`{score:.2f}`")
        else:
            st.markdown(f"`{weighted:.3f}`")

    # Evidence text below the bar
    st.caption(f"    {evidence}  *(weight: {weight:.2f}, raw: {score:.2f})*")

# ---------------------------------------------------------------------------
# Signal weight reference
# ---------------------------------------------------------------------------

st.markdown("---")

with st.expander("Signal Weight Reference"):
    df_weights = run_query("""
        SELECT signal_type, signal_name, signal_weight, signal_description, is_risk_signal
        FROM CUSTOMER360_DB.ANALYTICS.SIGNAL_WEIGHTS
        ORDER BY signal_weight DESC
    """)
    if not df_weights.empty:
        st.dataframe(df_weights, use_container_width=True, hide_index=True)
    st.caption("Weights sum to 1.0. Cross-sell opportunity has weight 0 (informational only).")

# ---------------------------------------------------------------------------
# Explanation text
# ---------------------------------------------------------------------------

st.markdown("---")
st.subheader("Risk Explanation")

# Build a natural-language summary from the top signals
active_signals = df_signals[df_signals["WEIGHTED_SCORE"] > 0].head(3)
if not active_signals.empty:
    parts = []
    for _, sig in active_signals.iterrows():
        parts.append(str(sig["EVIDENCE_TEXT"]))
    explanation = ". ".join(parts) + "."
    st.markdown(f"> {explanation}")
else:
    st.success("No elevated risk signals detected.")

st.caption("All risk signals are deterministic and computed from structured + AI-enriched data. No ML models are used.")

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

st.markdown("---")
col1, col2, _ = st.columns([1, 1, 3])
with col1:
    if st.button("← Customer 360"):
        st.switch_page("pages/01_Customer360.py")
with col2:
    if st.button("View Recommendations →"):
        st.switch_page("pages/03_NBA_Recommendations.py")
