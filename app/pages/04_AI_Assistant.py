"""
AI Assistant — Conversational chatbot powered by Cortex Agent.
"""

import json
import streamlit as st
from helpers import get_session

AGENT_FQN = "CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT"

st.title("AI Assistant")
st.caption("Ask questions about customers, policies, risk signals, and recommendations")

# --- session state for chat history ---
if "messages" not in st.session_state:
    st.session_state.messages = []
if "thread_id" not in st.session_state:
    st.session_state.thread_id = None
if "parent_message_id" not in st.session_state:
    st.session_state.parent_message_id = 0


def call_agent(user_text: str) -> str:
    """Send a message to the Cortex Agent and return the assistant's text reply."""
    session = get_session()

    request_body = {
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": user_text}],
            }
        ],
    }

    if st.session_state.thread_id is not None:
        request_body["thread_id"] = st.session_state.thread_id
        request_body["parent_message_id"] = st.session_state.parent_message_id

    request_json = json.dumps(request_body).replace("'", "\\'")
    create_thread = "TRUE" if st.session_state.thread_id is None else "FALSE"

    sql = (
        f"SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN("
        f"'{AGENT_FQN}', '{request_json}', {create_thread}"
        f") AS resp"
    )

    result = session.sql(sql).collect()
    raw = result[0]["RESP"]
    if raw is None:
        return "Agent returned no response."

    resp = json.loads(str(raw)) if not isinstance(raw, dict) else raw

    # Handle error responses
    if "message" in resp and "content" not in resp:
        return f"Agent error: {resp.get('message', 'Unknown error')}"

    # Extract thread_id from metadata for multi-turn conversations
    metadata = resp.get("metadata", {})
    if "thread_id" in metadata:
        st.session_state.thread_id = metadata["thread_id"]
    if "assistant_message_id" in metadata:
        st.session_state.parent_message_id = metadata["assistant_message_id"]

    # Extract text content from the response
    content_parts = resp.get("content", [])
    text_parts = [p["text"] for p in content_parts if p.get("type") == "text"]
    return "\n\n".join(text_parts) if text_parts else "No response from agent."


# --- sidebar controls ---
with st.sidebar:
    st.markdown("---")
    st.subheader("Chat Controls")
    if st.button("Clear conversation", width="stretch"):
        st.session_state.messages = []
        st.session_state.thread_id = None
        st.session_state.parent_message_id = 0
        st.session_state.pending_question = None
        st.rerun()

    st.markdown("---")
    st.markdown("**Suggested questions:**")
    st.caption("Structured (Analyst)")
    suggestions = [
        "How many high-risk customers do we have?",
        "What is the risk profile for CUST-001?",
        "Which customers are renewing in the next 30 days?",
    ]
    for s in suggestions:
        if st.button(s, key=f"sug_{s[:20]}", width="stretch"):
            st.session_state.pending_question = s
            st.rerun()

    st.markdown("---")
    st.caption("Unstructured (Search)")
    suggestions = [
        "What does Maria Chen's auto policy cover?",
        "Show me the latest email from CUST-005",
        "What is the escalation procedure for complaints?",
        "What did CUST-002 say in their last call?",
        "What are the cross-sell eligibility rules?",
        "What is the renewal discount policy?",
    ]
    for s in suggestions:
        if st.button(s, key=f"sug_{s[:20]}", width="stretch"):
            st.session_state.pending_question = s
            st.rerun()

# --- determine the active prompt (chat input or suggestion click) ---
pending = st.session_state.pop("pending_question", None) if "pending_question" in st.session_state else None
chat_prompt = st.chat_input("Ask about customers, risk, claims, recommendations...")
active_prompt = pending or chat_prompt

# --- render existing messages ---
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

# --- process the active prompt ---
if active_prompt:
    st.session_state.messages.append({"role": "user", "content": active_prompt})
    with st.chat_message("user"):
        st.markdown(active_prompt)

    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            try:
                reply = call_agent(active_prompt)
            except Exception as e:
                reply = f"Error contacting agent: {e}"
        st.markdown(reply)

    st.session_state.messages.append({"role": "assistant", "content": reply})
