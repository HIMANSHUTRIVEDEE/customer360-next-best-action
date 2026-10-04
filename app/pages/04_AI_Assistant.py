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

    # If we already have a thread, continue the conversation
    if st.session_state.thread_id is not None:
        request_body["thread_id"] = st.session_state.thread_id
        request_body["parent_message_id"] = st.session_state.parent_message_id

    request_json = json.dumps(request_body)
    create_thread = st.session_state.thread_id is None

    sql = f"""
        SELECT TRY_PARSE_JSON(
            SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                '{AGENT_FQN}',
                $${request_json}$$,
                {str(create_thread).upper()}
            )
        ) AS resp
    """

    result = session.sql(sql).collect()
    resp = json.loads(result[0]["RESP"])

    # Extract thread_id from metadata for multi-turn conversations
    metadata = resp.get("metadata", {})
    if "thread_id" in metadata:
        st.session_state.thread_id = metadata["thread_id"]
    if "message_id" in metadata:
        st.session_state.parent_message_id = metadata["message_id"]

    # Extract text content from the response
    content_parts = resp.get("content", [])
    text_parts = [p["text"] for p in content_parts if p.get("type") == "text"]
    return "\n\n".join(text_parts) if text_parts else "No response from agent."


# --- render existing messages ---
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

# --- chat input ---
if prompt := st.chat_input("Ask about customers, risk, claims, recommendations..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            try:
                reply = call_agent(prompt)
            except Exception as e:
                reply = f"Error contacting agent: {e}"
        st.markdown(reply)

    st.session_state.messages.append({"role": "assistant", "content": reply})

# --- sidebar controls ---
with st.sidebar:
    st.markdown("---")
    st.subheader("Chat Controls")
    if st.button("Clear conversation", use_container_width=True):
        st.session_state.messages = []
        st.session_state.thread_id = None
        st.session_state.parent_message_id = 0
        st.rerun()

    st.markdown("---")
    st.markdown("**Suggested questions:**")
    suggestions = [
        "How many high-risk customers do we have?",
        "What is the risk profile for CUST-001?",
        "Which customers are renewing in the next 30 days?",
        "What recommendation was generated for CUST-005?",
        "What is the average risk score across all customers?",
    ]
    for s in suggestions:
        if st.button(s, key=f"sug_{s[:20]}", use_container_width=True):
            st.session_state.messages.append({"role": "user", "content": s})
            st.rerun()
