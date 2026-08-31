"""
Home — Customer search and high-risk dashboard.
"""

import streamlit as st

# Import shared helpers from app.py
from helpers import run_query

# ---------------------------------------------------------------------------
# Landing page — customer search
# ---------------------------------------------------------------------------

st.title("Customer 360 — Next Best Action")
st.caption("Decision-support for insurance service representatives")

st.markdown("---")

# Search bar
search_term = st.text_input(
    "Search by customer name or ID",
    placeholder="e.g. Maria Chen or CUST-001",
    key="customer_search",
)

if search_term:
    safe_term = search_term.replace("'", "''")
    df = run_query(f"""
        SELECT
            customer_id,
            first_name || ' ' || last_name AS customer_name,
            risk_tier,
            composite_risk_score,
            days_to_renewal,
            active_policies,
            product_holdings,
            nba_action_name,
            nba_confidence_level,
            system_status
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
        WHERE LOWER(first_name || ' ' || last_name) LIKE LOWER('%{safe_term}%')
           OR LOWER(customer_id) LIKE LOWER('%{safe_term}%')
        ORDER BY composite_risk_score DESC
        LIMIT 20
    """)

    if df.empty:
        st.warning("No customers found.")
    else:
        st.subheader(f"{len(df)} result(s)")

        def risk_color(tier):
            return {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}.get(
                str(tier).lower(), "⚪"
            )

        df["RISK"] = df["RISK_TIER"].apply(risk_color) + " " + df["RISK_TIER"].astype(str)

        for _, row in df.iterrows():
            col1, col2, col3, col4 = st.columns([2, 1, 2, 1])
            with col1:
                st.markdown(f"**{row['CUSTOMER_NAME']}** (`{row['CUSTOMER_ID']}`)")
            with col2:
                st.markdown(row["RISK"])
            with col3:
                renewal_txt = (
                    f"Renewal in **{int(row['DAYS_TO_RENEWAL'])}d**"
                    if row["DAYS_TO_RENEWAL"] and row["DAYS_TO_RENEWAL"] > 0
                    else "No upcoming renewal"
                )
                st.markdown(renewal_txt)
            with col4:
                if st.button("View", key=f"btn_{row['CUSTOMER_ID']}"):
                    st.session_state["selected_customer_id"] = row["CUSTOMER_ID"]
                    st.switch_page("pages/01_Customer360.py")

else:
    # Default: show high-risk customers
    st.subheader("High-Risk Customers")
    df_risk = run_query("""
        SELECT
            customer_id,
            first_name || ' ' || last_name AS customer_name,
            risk_tier,
            composite_risk_score,
            days_to_renewal,
            nba_action_name,
            nba_confidence_level,
            negative_count_90d
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
        WHERE risk_tier IN ('critical', 'high')
        ORDER BY composite_risk_score DESC
        LIMIT 10
    """)

    if not df_risk.empty:
        st.dataframe(
            df_risk,
            use_container_width=True,
            hide_index=True,
            column_config={
                "CUSTOMER_ID": "ID",
                "CUSTOMER_NAME": "Customer",
                "RISK_TIER": "Risk",
                "COMPOSITE_RISK_SCORE": st.column_config.ProgressColumn(
                    "Risk Score", min_value=0, max_value=1, format="%.2f"
                ),
                "DAYS_TO_RENEWAL": "Renewal (days)",
                "NBA_ACTION_NAME": "Recommended Action",
                "NBA_CONFIDENCE_LEVEL": "Confidence",
                "NEGATIVE_COUNT_90D": "Neg. Interactions (90d)",
            },
        )

    # Quick stats
    st.markdown("---")
    c1, c2, c3, c4 = st.columns(4)
    stats = run_query("""
        SELECT
            COUNT(*) AS total,
            COUNT(CASE WHEN risk_tier IN ('critical','high') THEN 1 END) AS high_risk,
            COUNT(CASE WHEN days_to_renewal <= 30 AND days_to_renewal > 0 THEN 1 END) AS renewing_30d,
            COUNT(CASE WHEN system_status = 'full' THEN 1 END) AS fully_operational
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
    """)
    if not stats.empty:
        r = stats.iloc[0]
        c1.metric("Total Customers", int(r["TOTAL"]))
        c2.metric("High/Critical Risk", int(r["HIGH_RISK"]))
        c3.metric("Renewing in 30d", int(r["RENEWING_30D"]))
        c4.metric("Fully Operational", int(r["FULLY_OPERATIONAL"]))
