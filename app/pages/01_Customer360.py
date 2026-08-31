"""
Page 1: Customer 360 Profile
Unified view: identity, policies, payments, interaction timeline with sentiment.
"""

import streamlit as st
import json

from helpers import run_query


# ---------------------------------------------------------------------------
# Customer selection
# ---------------------------------------------------------------------------

customer_id = st.session_state.get("selected_customer_id")

if not customer_id:
    st.info("Select a customer from the home page, or enter an ID below.")
    customer_id = st.text_input("Customer ID", placeholder="CUST-001")
    if customer_id:
        st.session_state["selected_customer_id"] = customer_id
    else:
        st.stop()

# ---------------------------------------------------------------------------
# Load customer data
# ---------------------------------------------------------------------------

safe_id = customer_id.replace("'", "''")
df = run_query(f"""
    SELECT * FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
    WHERE customer_id = '{safe_id}'
""")

if df.empty:
    st.error(f"Customer `{customer_id}` not found.")
    st.stop()

c = df.iloc[0]

# ---------------------------------------------------------------------------
# System status banner
# ---------------------------------------------------------------------------

if c["SYSTEM_STATUS"] != "full":
    st.warning(c.get("SYSTEM_MESSAGE", "System operating in degraded mode."))

# ---------------------------------------------------------------------------
# Section 1: Customer header
# ---------------------------------------------------------------------------

st.title(f"{c['FIRST_NAME']} {c['LAST_NAME']}")

h1, h2, h3, h4, h5 = st.columns(5)
h1.metric("Customer ID", c["CUSTOMER_ID"])
h2.metric("Status", str(c["CUSTOMER_STATUS"]).title())
h3.metric("Since", str(c["CUSTOMER_SINCE"]))
h4.metric("Risk", str(c["RISK_TIER"]).upper(), delta=str(c["RISK_DIRECTION"]))
h5.metric("Days to Renewal", int(c["DAYS_TO_RENEWAL"]) if c["DAYS_TO_RENEWAL"] else "N/A")

st.markdown("---")

# ---------------------------------------------------------------------------
# Section 2: Policy & payment summary
# ---------------------------------------------------------------------------

col_left, col_right = st.columns(2)

with col_left:
    st.subheader("Policies")
    p1, p2, p3 = st.columns(3)
    p1.metric("Active Policies", int(c["ACTIVE_POLICIES"]))
    p2.metric("Products", str(c.get("PRODUCT_HOLDINGS", "N/A")))
    p3.metric("Annual Premium", f"${c['TOTAL_ANNUAL_PREMIUM']:,.0f}")

    if c["NEAREST_RENEWAL_DATE"]:
        days = int(c["DAYS_TO_RENEWAL"]) if c["DAYS_TO_RENEWAL"] else None
        if days is not None and days <= 14:
            st.error(f"URGENT: Renewal on {c['NEAREST_RENEWAL_DATE']} ({days} days)")
        elif days is not None and days <= 30:
            st.warning(f"Approaching: Renewal on {c['NEAREST_RENEWAL_DATE']} ({days} days)")
        else:
            st.info(f"Next renewal: {c['NEAREST_RENEWAL_DATE']}")

with col_right:
    st.subheader("Payments")
    pay1, pay2, pay3, pay4 = st.columns(4)
    pay1.metric("On Time", int(c["PAYMENTS_ON_TIME"]))
    pay2.metric("Late", int(c["PAYMENTS_LATE"]))
    pay3.metric("Missed", int(c["PAYMENTS_MISSED"]))
    pay4.metric("Total", int(c["TOTAL_PAYMENTS"]))

    if int(c["PAYMENTS_LATE"]) + int(c["PAYMENTS_MISSED"]) == 0:
        st.success("All payments current")
    else:
        late_pct = (int(c["PAYMENTS_LATE"]) + int(c["PAYMENTS_MISSED"])) / max(int(c["TOTAL_PAYMENTS"]), 1) * 100
        st.warning(f"{late_pct:.0f}% of payments late or missed")

# ---------------------------------------------------------------------------
# Section 3: Claims
# ---------------------------------------------------------------------------

st.markdown("---")
st.subheader("Claims")
cl1, cl2, cl3, cl4 = st.columns(4)
cl1.metric("Total Claims", int(c["TOTAL_CLAIMS"]))
cl2.metric("Open", int(c["OPEN_CLAIMS"]))
cl3.metric("Settled", int(c["SETTLED_CLAIMS"]))
cl4.metric("Denied", int(c["DENIED_CLAIMS"]))

# ---------------------------------------------------------------------------
# Section 4: Sentiment summary
# ---------------------------------------------------------------------------

st.markdown("---")
st.subheader("Sentiment Analysis (AI-Derived)")

if c["HAS_ENRICHMENT"]:
    s1, s2, s3, s4 = st.columns(4)
    s1.metric(
        "Negative (90d)",
        int(c["NEGATIVE_COUNT_90D"]),
        delta=f"{c['SENTIMENT_DIRECTION']}" if c["SENTIMENT_DIRECTION"] != "insufficient_data" else None,
        delta_color="inverse",
    )
    s2.metric("Positive (90d)", int(c["POSITIVE_COUNT_90D"]))
    s3.metric(
        "Avg Sentiment",
        f"{c['AVG_SENTIMENT_90D']:.2f}" if c["AVG_SENTIMENT_90D"] else "N/A",
    )
    s4.metric("Enrichment Coverage", f"{c['ENRICHMENT_COVERAGE_PCT']:.0%}")
else:
    st.info("No AI-enriched interactions available for this customer.")

# ---------------------------------------------------------------------------
# Section 5: Interaction timeline
# ---------------------------------------------------------------------------

st.markdown("---")
st.subheader("Recent Interactions")

df_interactions = run_query(f"""
    SELECT
        interaction_id,
        interaction_date,
        channel,
        direction,
        disposition,
        sentiment_label,
        sentiment_score,
        summary,
        primary_topic,
        primary_intent,
        urgency_level,
        is_complaint,
        enrichment_status
    FROM CUSTOMER360_DB.ANALYTICS.INTERACTIONS_ENRICHED
    WHERE customer_id = '{safe_id}'
    ORDER BY interaction_date DESC
""")

if df_interactions.empty:
    st.info("No interactions recorded.")
else:
    for _, ix in df_interactions.iterrows():
        sent = ix.get("SENTIMENT_LABEL")
        sent_icon = {"negative": "🔴", "neutral": "🟡", "positive": "🟢"}.get(
            str(sent).lower(), "⚪"
        )
        urgency = str(ix.get("URGENCY_LEVEL", "")).lower()
        urgency_badge = {
            "critical": "🚨 CRITICAL",
            "high": "⚠️ HIGH",
            "medium": "📋 MEDIUM",
            "low": "✅ LOW",
        }.get(urgency, "")

        date_str = str(ix["INTERACTION_DATE"])[:10]
        channel = str(ix["CHANNEL"]).upper()
        disposition = str(ix.get("DISPOSITION", ""))

        header = f"{sent_icon} **{date_str}** — {channel} ({disposition})"
        if urgency_badge:
            header += f" | {urgency_badge}"
        if ix.get("IS_COMPLAINT"):
            header += " | **COMPLAINT**"

        with st.expander(header, expanded=(urgency in ("critical", "high"))):
            if ix.get("ENRICHMENT_STATUS") == "completed":
                if ix.get("SUMMARY"):
                    st.markdown(f"**Summary:** {ix['SUMMARY']}")
                ic1, ic2, ic3 = st.columns(3)
                ic1.markdown(f"**Topic:** {ix.get('PRIMARY_TOPIC', 'N/A')}")
                ic2.markdown(f"**Intent:** {ix.get('PRIMARY_INTENT', 'N/A')}")
                ic3.markdown(
                    f"**Sentiment:** {sent} ({ix['SENTIMENT_SCORE']:.2f})"
                    if ix.get("SENTIMENT_SCORE") is not None
                    else "**Sentiment:** N/A"
                )
                st.caption("AI-derived — model: cortex.sentiment + mistral-7b")
            else:
                st.caption(f"Enrichment status: {ix.get('ENRICHMENT_STATUS', 'unknown')}")

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

st.markdown("---")
col_nav1, col_nav2, _ = st.columns([1, 1, 3])
with col_nav1:
    if st.button("View Risk Signals →"):
        st.switch_page("pages/02_Risk_Signals.py")
with col_nav2:
    if st.button("View Recommendations →"):
        st.switch_page("pages/03_NBA_Recommendations.py")
