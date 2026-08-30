"""
Page 3: NBA Recommendations
Primary recommendation, alternatives, evidence, confidence, and approval workflow.
"""

import streamlit as st
from datetime import datetime

st.set_page_config(page_title="Recommendations", page_icon="🎯", layout="wide")


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


def execute_sql(sql: str):
    get_session().sql(sql).collect()


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

df_customer = run_query(f"""
    SELECT first_name, last_name, risk_tier, composite_risk_score,
           nba_action_name, nba_confidence_level, system_status, system_message
    FROM CUSTOMER360_DB.ANALYTICS.CUSTOMER_360_ENRICHED
    WHERE customer_id = '{safe_id}'
""")

df_nba = run_query(f"""
    SELECT action_rank, action_id, action_type, action_name, action_description,
           action_category, relevance_score, safety_score, final_score,
           risk_tier, composite_risk_score, overall_direction,
           confidence_level, confidence_score,
           evidence_signals, data_completeness, eligibility_check
    FROM CUSTOMER360_DB.ANALYTICS.NBA_RECOMMENDATIONS
    WHERE customer_id = '{safe_id}'
    ORDER BY action_rank
""")

if df_customer.empty:
    st.error(f"Customer `{customer_id}` not found.")
    st.stop()

cust = df_customer.iloc[0]
st.title(f"Recommendations — {cust['FIRST_NAME']} {cust['LAST_NAME']}")

# ---------------------------------------------------------------------------
# Fallback: no recommendation available
# ---------------------------------------------------------------------------

if cust["SYSTEM_STATUS"] != "full" and cust.get("SYSTEM_MESSAGE"):
    st.warning(cust["SYSTEM_MESSAGE"])

if df_nba.empty:
    st.info("No recommendations available for this customer. Please review the Customer 360 context manually.")
    if st.button("← Customer 360"):
        st.switch_page("pages/01_Customer360.py")
    st.stop()

# ---------------------------------------------------------------------------
# Primary recommendation card
# ---------------------------------------------------------------------------

primary = df_nba[df_nba["ACTION_RANK"] == 1].iloc[0]

st.subheader("Primary Recommendation")

# Confidence badge
conf = str(primary["CONFIDENCE_LEVEL"]).lower()
conf_colors = {"high": "🟢", "medium_high": "🟡", "medium": "🟠", "low": "🔴"}
conf_icon = conf_colors.get(conf, "⚪")

rc1, rc2, rc3, rc4 = st.columns(4)
rc1.metric("Action", str(primary["ACTION_NAME"]))
rc2.metric("Category", str(primary["ACTION_CATEGORY"]).title())
rc3.metric("Score", f"{primary['FINAL_SCORE']:.2f}")
rc4.metric("Confidence", f"{conf_icon} {conf.replace('_', ' ').title()}")

st.markdown(f"> {primary['ACTION_DESCRIPTION']}")

# ---------------------------------------------------------------------------
# Evidence trail
# ---------------------------------------------------------------------------

st.markdown("---")
st.subheader("Supporting Evidence")

# Parse evidence_signals array
evidence = primary.get("EVIDENCE_SIGNALS")
if evidence is not None:
    import json

    # Handle both string and list types
    if isinstance(evidence, str):
        try:
            signals = json.loads(evidence)
        except (json.JSONDecodeError, TypeError):
            signals = []
    elif isinstance(evidence, list):
        signals = evidence
    else:
        signals = []

    # Show top contributing signals
    active = [s for s in signals if isinstance(s, dict) and float(s.get("weighted_score", 0)) > 0]
    active.sort(key=lambda x: float(x.get("weighted_score", 0)), reverse=True)

    if active:
        for sig in active[:5]:
            direction_icons = {"worsening": "📉", "improving": "📈", "stable": "➡️"}
            d = str(sig.get("direction", "stable"))
            icon = direction_icons.get(d, "")
            ev_text = sig.get("evidence", "")
            w_score = float(sig.get("weighted_score", 0))
            st.markdown(f"- {icon} **{ev_text}** *(weighted: {w_score:.3f})*")
    else:
        st.info("No active risk signals contributing to this recommendation.")
else:
    st.info("Evidence data not available.")

# Data completeness
completeness = primary.get("DATA_COMPLETENESS")
if completeness is not None:
    import json

    if isinstance(completeness, str):
        try:
            dc = json.loads(completeness)
        except (json.JSONDecodeError, TypeError):
            dc = {}
    elif isinstance(completeness, dict):
        dc = completeness
    else:
        dc = {}

    if dc:
        st.caption(
            f"Data completeness: {dc.get('enriched_interactions', 0)} enriched interactions, "
            f"{dc.get('risk_signals_computed', 0)} risk signals, "
            f"enrichment coverage {float(dc.get('enrichment_coverage_pct', 0)):.0%}"
        )

# ---------------------------------------------------------------------------
# Scoring breakdown
# ---------------------------------------------------------------------------

with st.expander("Scoring Details"):
    sc1, sc2, sc3 = st.columns(3)
    sc1.metric("Relevance", f"{primary['RELEVANCE_SCORE']:.3f}")
    sc2.metric("Safety", f"{primary['SAFETY_SCORE']:.3f}")
    sc3.metric("Final (R × S)", f"{primary['FINAL_SCORE']:.3f}")
    st.caption("Final score = relevance × safety. Higher relevance means the action addresses more active signals. Higher safety means lower risk of escalation.")

# ---------------------------------------------------------------------------
# Alternative actions
# ---------------------------------------------------------------------------

st.markdown("---")
alternatives = df_nba[df_nba["ACTION_RANK"] > 1]

if not alternatives.empty:
    st.subheader("Alternative Actions")
    for _, alt in alternatives.iterrows():
        with st.expander(f"#{int(alt['ACTION_RANK'])} — {alt['ACTION_NAME']} (score: {alt['FINAL_SCORE']:.2f})"):
            st.markdown(alt["ACTION_DESCRIPTION"])
            ac1, ac2, ac3 = st.columns(3)
            ac1.markdown(f"**Category:** {str(alt['ACTION_CATEGORY']).title()}")
            ac2.markdown(f"**Relevance:** {alt['RELEVANCE_SCORE']:.3f}")
            ac3.markdown(f"**Safety:** {alt['SAFETY_SCORE']:.3f}")

# ---------------------------------------------------------------------------
# Human approval gate
# ---------------------------------------------------------------------------

st.markdown("---")
st.subheader("Decision")
st.caption("The system recommends; you decide. No action is taken without your explicit approval.")

# Check if already approved in this session
approval_key = f"approved_{customer_id}"
if st.session_state.get(approval_key):
    st.success(f"Decision recorded for {cust['FIRST_NAME']} {cust['LAST_NAME']}.")
    st.json(st.session_state[approval_key])
else:
    def _log_decision(decision_type, action_text, notes=None):
        """Write to all three DECISION tables in one call. Falls back to session-only."""
        safe_action_name = str(primary["ACTION_NAME"]).replace("'", "''")
        safe_action_type = str(primary["ACTION_TYPE"]).replace("'", "''")
        safe_action_desc = str(primary["ACTION_DESCRIPTION"]).replace("'", "''")
        safe_action_text = str(action_text).replace("'", "''")
        safe_notes = str(notes).replace("'", "''") if notes else ""
        conf_level = str(primary["CONFIDENCE_LEVEL"])
        conf_score = float(primary["CONFIDENCE_SCORE"])
        risk = str(primary["RISK_TIER"])
        risk_score = float(primary["COMPOSITE_RISK_SCORE"])
        final = float(primary["FINAL_SCORE"])

        try:
            # 1. RECOMMENDATION_LOG — what the system suggested
            execute_sql(f"""
                INSERT INTO CUSTOMER360_DB.DECISION.RECOMMENDATION_LOG
                (recommendation_log_id, customer_id, action_type, action_name,
                 action_description, confidence_level, confidence_score,
                 risk_tier, composite_risk_score, final_score)
                SELECT UUID_STRING(), '{safe_id}', '{safe_action_type}', '{safe_action_name}',
                       '{safe_action_desc}', '{conf_level}', {conf_score},
                       '{risk}', {risk_score}, {final}
            """)

            # Get the recommendation_log_id just inserted
            rec_id_df = run_query(f"""
                SELECT recommendation_log_id
                FROM CUSTOMER360_DB.DECISION.RECOMMENDATION_LOG
                WHERE customer_id = '{safe_id}'
                ORDER BY created_at DESC LIMIT 1
            """)
            rec_log_id = str(rec_id_df.iloc[0]["RECOMMENDATION_LOG_ID"])
            safe_rec_id = rec_log_id.replace("'", "''")

            # 2. DECISION_AUDIT_EVENT — the state transition
            execute_sql(f"""
                INSERT INTO CUSTOMER360_DB.DECISION.DECISION_AUDIT_EVENT
                (event_id, recommendation_log_id, customer_id,
                 event_type, event_notes)
                SELECT UUID_STRING(), '{safe_rec_id}', '{safe_id}',
                       '{decision_type}',
                       '{safe_notes}'
            """)

            # 3. FOLLOW_UP_LOG — only for approved or modified (not rejected)
            if decision_type in ("approved", "modified"):
                execute_sql(f"""
                    INSERT INTO CUSTOMER360_DB.DECISION.FOLLOW_UP_LOG
                    (follow_up_id, recommendation_log_id, customer_id,
                     follow_up_status, action_taken, notes)
                    SELECT UUID_STRING(), '{safe_rec_id}', '{safe_id}',
                           '{decision_type}', '{safe_action_text}',
                           NULLIF('{safe_notes}', '')
                """)

            st.session_state[approval_key] = {
                "decision": decision_type,
                "action": str(primary["ACTION_NAME"]),
                "customer_id": customer_id,
                "recommendation_log_id": rec_log_id,
                "timestamp": datetime.utcnow().isoformat(),
                "persisted": True,
            }
            return True

        except Exception:
            # DECISION tables may not exist — fall back to session-only
            st.session_state[approval_key] = {
                "decision": decision_type,
                "action": str(primary["ACTION_NAME"]),
                "customer_id": customer_id,
                "timestamp": datetime.utcnow().isoformat(),
                "persisted": False,
                "note": "Logged in session only (DECISION tables pending)",
            }
            return False

    decision_tabs = st.tabs(["Accept", "Modify", "Reject"])

    with decision_tabs[0]:
        st.markdown(f"Accept the primary recommendation: **{primary['ACTION_NAME']}**")
        if st.button("Accept Recommendation", type="primary", key="btn_accept"):
            ok = _log_decision("approved", str(primary["ACTION_DESCRIPTION"]))
            if ok:
                st.success("Decision logged to RECOMMENDATION_LOG + FOLLOW_UP_LOG + DECISION_AUDIT_EVENT.")
            else:
                st.success("Decision recorded in session. (DECISION tables pending for persistent logging.)")
            st.rerun()

    with decision_tabs[1]:
        st.markdown("Modify the recommended action before accepting.")
        modified_action = st.text_area(
            "Modified action",
            value=str(primary["ACTION_DESCRIPTION"]),
            key="modify_text",
        )
        modification_reason = st.text_input("Reason for modification", key="modify_reason")
        if st.button("Accept Modified Action", key="btn_modify"):
            ok = _log_decision("modified", modified_action, modification_reason)
            if ok:
                st.success("Modified decision logged to all DECISION tables.")
            else:
                st.success("Modified decision recorded in session.")
            st.rerun()

    with decision_tabs[2]:
        rejection_reason = st.text_input("Reason for rejection", key="reject_reason")
        if st.button("Reject Recommendation", key="btn_reject"):
            ok = _log_decision("rejected", str(primary["ACTION_NAME"]), rejection_reason)
            if ok:
                st.warning("Rejection logged to RECOMMENDATION_LOG + DECISION_AUDIT_EVENT. No follow-up created.")
            else:
                st.warning("Rejection recorded in session.")
            st.rerun()

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

st.markdown("---")
col1, col2, _ = st.columns([1, 1, 3])
with col1:
    if st.button("← Customer 360"):
        st.switch_page("pages/01_Customer360.py")
with col2:
    if st.button("← Risk Signals"):
        st.switch_page("pages/02_Risk_Signals.py")
