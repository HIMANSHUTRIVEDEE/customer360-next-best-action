"""
Generate unstructured documents for Cortex Search integration.
Reads existing synthetic CSVs and produces:
  1. Policy summary documents (one per policy with coverage details)
  2. Customer emails (complaints, inquiries, renewal questions)
  3. Enriched transcripts (reformatted from existing transcripts.csv)
  4. Knowledge base articles (internal SOPs and procedures)

Output: data/generated/unstructured_documents.csv
"""

import csv
import random
from datetime import datetime
from pathlib import Path
from collections import defaultdict

SEED = 42
random.seed(SEED)
OUTPUT_DIR = Path(__file__).parent / "generated"
TODAY = datetime.now().strftime("%Y-%m-%d")


def read_csv(filename):
    path = OUTPUT_DIR / filename
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def fmt_money(val):
    return f"${float(val):,.2f}"


# ── 1. Policy Summary Documents ──────────────────────────────────────────────

def generate_policy_summaries(customers, policies, coverages):
    cust_map = {c["customer_id"]: c for c in customers}
    cov_by_policy = defaultdict(list)
    for cov in coverages:
        cov_by_policy[cov["policy_id"]].append(cov)

    docs = []
    for pol in policies:
        cid = pol["customer_id"]
        cust = cust_map.get(cid, {})
        name = f"{cust.get('first_name', '')} {cust.get('last_name', '')}".strip()
        ptype = pol["product_type"].replace("_", " ").title()
        covs = cov_by_policy.get(pol["policy_id"], [])

        cov_lines = []
        for c in covs:
            ct = c["coverage_type"].replace("_", " ").title()
            cov_lines.append(
                f"  - {ct}: Limit {fmt_money(c['limit_amount'])}, "
                f"Deductible {fmt_money(c['deductible_amount'])}"
            )
        cov_text = "\n".join(cov_lines) if cov_lines else "  No coverages on file."

        content = (
            f"POLICY SUMMARY DOCUMENT\n"
            f"=======================\n\n"
            f"Policy Number: {pol['policy_id']}\n"
            f"Policy Type: {ptype} Insurance\n"
            f"Policyholder: {name} ({cid})\n"
            f"Address: {cust.get('address_line_1', '')}, {cust.get('city', '')}, "
            f"{cust.get('state', '')} {cust.get('postal_code', '')}\n\n"
            f"Effective Date: {pol['effective_date']}\n"
            f"Expiration Date: {pol['expiration_date']}\n"
            f"Status: {pol['status'].title()}\n"
            f"Annual Premium: {fmt_money(pol['premium_amount'])}\n"
            f"Payment Frequency: {pol['payment_frequency'].replace('_', ' ').title()}\n\n"
            f"COVERAGES\n"
            f"---------\n"
            f"{cov_text}\n\n"
            f"IMPORTANT NOTICES\n"
            f"-----------------\n"
            f"This policy is subject to all terms, conditions, and exclusions "
            f"described in the full policy contract. Coverage limits represent the "
            f"maximum amount payable per occurrence. Deductibles are the amount the "
            f"policyholder must pay before coverage applies. Premium amounts are "
            f"subject to change at renewal based on claims history, coverage changes, "
            f"and applicable rate filings. Contact your agent for questions about "
            f"your coverage.\n"
        )

        docs.append({
            "doc_id": f"DOC-POL-{pol['policy_id'].split('-')[1]}",
            "customer_id": cid,
            "policy_id": pol["policy_id"],
            "interaction_id": "",
            "doc_type": "policy_summary",
            "title": f"{ptype} Insurance Policy {pol['policy_id']} for {name}",
            "content": content,
            "created_at": pol.get("bound_date", pol["effective_date"]) + "T00:00:00",
        })

    return docs


# ── 2. Customer Emails ───────────────────────────────────────────────────────

EMAIL_TEMPLATES = {
    "complaint_claim_delay": {
        "subject": "Frustrated with claim processing delay",
        "body": (
            "Dear Customer Service,\n\n"
            "I am writing to express my frustration with the delay in processing "
            "my claim. It has been over {days} days since I filed and I have not "
            "received any meaningful update on the status. Every time I call, I am "
            "told someone will get back to me, but nobody does.\n\n"
            "As a loyal customer of {years} years, I expect better service than this. "
            "I need someone to take ownership of this issue and provide me with a "
            "clear timeline for resolution.\n\n"
            "Please contact me at your earliest convenience.\n\n"
            "Sincerely,\n{name}\nPolicy: {policy_id}\n"
        ),
    },
    "complaint_premium_increase": {
        "subject": "Question about premium increase on my policy",
        "body": (
            "Hello,\n\n"
            "I just received my renewal notice and was shocked to see that my "
            "premium has increased significantly. I have had no claims in the past "
            "year and my driving record is clean. I do not understand why my rate "
            "went up.\n\n"
            "Can someone please review my account and explain the increase? I have "
            "been a customer for {years} years and would hate to have to shop around "
            "for a new provider, but I need this to make sense.\n\n"
            "Thank you,\n{name}\nPolicy: {policy_id}\n"
        ),
    },
    "inquiry_coverage": {
        "subject": "Coverage question for my {product_type} policy",
        "body": (
            "Hi there,\n\n"
            "I would like to understand what exactly is covered under my current "
            "{product_type} policy ({policy_id}). Specifically, I want to know:\n\n"
            "1. What are my current coverage limits?\n"
            "2. What is my deductible for each type of coverage?\n"
            "3. Are there any gaps in my coverage I should be aware of?\n\n"
            "I want to make sure I have adequate protection. Please send me a "
            "detailed breakdown or schedule a call to discuss.\n\n"
            "Best regards,\n{name}\n"
        ),
    },
    "inquiry_renewal": {
        "subject": "Upcoming renewal - what are my options?",
        "body": (
            "Dear Team,\n\n"
            "My {product_type} policy ({policy_id}) is coming up for renewal on "
            "{expiration_date}. Before it renews, I would like to explore my "
            "options:\n\n"
            "- Can I get a multi-policy discount if I bundle my coverages?\n"
            "- Are there any loyalty discounts available for long-term customers?\n"
            "- What would happen to my rate if I increased my deductible?\n\n"
            "I appreciate your help and look forward to hearing back.\n\n"
            "Thanks,\n{name}\n"
        ),
    },
    "positive_feedback": {
        "subject": "Thank you for the excellent service",
        "body": (
            "Hello,\n\n"
            "I just wanted to take a moment to thank your team for the excellent "
            "service I received recently. My representative was knowledgeable, "
            "patient, and resolved my issue quickly.\n\n"
            "It is refreshing to work with a company that values its customers. "
            "I have been with you for {years} years and experiences like this are "
            "why I stay.\n\n"
            "Keep up the great work!\n\n"
            "Warm regards,\n{name}\n"
        ),
    },
    "claim_followup": {
        "subject": "Follow-up on claim status",
        "body": (
            "Hi,\n\n"
            "I am following up on the status of my recent claim. I filed it "
            "approximately {days} days ago and wanted to check if there are any "
            "updates or if you need any additional documentation from me.\n\n"
            "My policy number is {policy_id} and my customer ID is {customer_id}. "
            "Please let me know the current status and expected timeline.\n\n"
            "Thank you,\n{name}\n"
        ),
    },
}


def generate_emails(customers, policies, interactions):
    cust_map = {c["customer_id"]: c for c in customers}
    pol_by_cust = defaultdict(list)
    for p in policies:
        pol_by_cust[p["customer_id"]].append(p)

    rng = random.Random(SEED + 100)
    docs = []
    doc_counter = 1

    int_by_cust = defaultdict(list)
    for inter in interactions:
        int_by_cust[inter["customer_id"]].append(inter)

    for cid, cust in cust_map.items():
        name = f"{cust['first_name']} {cust['last_name']}"
        cust_pols = pol_by_cust.get(cid, [])
        if not cust_pols:
            continue

        years = max(1, (datetime.now().year - int(cust["customer_since"][:4])))
        cust_ints = int_by_cust.get(cid, [])

        num_emails = rng.randint(1, 3)
        templates = list(EMAIL_TEMPLATES.keys())

        for _ in range(num_emails):
            tmpl_key = rng.choice(templates)
            tmpl = EMAIL_TEMPLATES[tmpl_key]
            pol = rng.choice(cust_pols)

            params = {
                "name": name,
                "customer_id": cid,
                "policy_id": pol["policy_id"],
                "product_type": pol["product_type"],
                "expiration_date": pol["expiration_date"],
                "years": years,
                "days": rng.randint(7, 45),
            }

            body = tmpl["body"].format(**params)
            subject = tmpl["subject"].format(**params)

            int_id = ""
            if cust_ints:
                chosen_int = rng.choice(cust_ints)
                int_id = chosen_int["interaction_id"]
                ts = chosen_int["interaction_date"]
            else:
                days_back = rng.randint(1, 90)
                from datetime import timedelta
                d = datetime.now() - timedelta(days=days_back)
                ts = d.strftime("%Y-%m-%dT%H:%M:%S")

            docs.append({
                "doc_id": f"DOC-EMAIL-{doc_counter:06d}",
                "customer_id": cid,
                "policy_id": pol["policy_id"],
                "interaction_id": int_id,
                "doc_type": "email",
                "title": subject,
                "content": body,
                "created_at": ts,
            })
            doc_counter += 1

    return docs


# ── 3. Enriched Transcripts ──────────────────────────────────────────────────

def generate_transcript_docs(transcripts, interactions, customers):
    cust_map = {c["customer_id"]: c for c in customers}
    int_map = {}
    for inter in interactions:
        int_map[inter["interaction_id"]] = inter

    docs = []
    for trx in transcripts:
        inter = int_map.get(trx["interaction_id"], {})
        cid = inter.get("customer_id", "")
        cust = cust_map.get(cid, {})
        name = f"{cust.get('first_name', '')} {cust.get('last_name', '')}".strip()
        channel = inter.get("channel", "unknown")
        disposition = inter.get("disposition", "unknown")

        ct = trx["content_type"].replace("_", " ").title()
        content = (
            f"INTERACTION TRANSCRIPT\n"
            f"=====================\n\n"
            f"Transcript ID: {trx['transcript_id']}\n"
            f"Interaction ID: {trx['interaction_id']}\n"
            f"Customer: {name} ({cid})\n"
            f"Channel: {channel.title()}\n"
            f"Type: {ct}\n"
            f"Disposition: {disposition.title()}\n"
            f"Date: {inter.get('interaction_date', '')}\n"
            f"Duration: {inter.get('duration_seconds', 'N/A')} seconds\n"
            f"Recording Consent: {trx['recording_consent_flag']}\n\n"
            f"CONTENT\n"
            f"-------\n"
            f"{trx['raw_text']}\n"
        )

        docs.append({
            "doc_id": f"DOC-TRX-{trx['transcript_id'].split('-')[1]}",
            "customer_id": cid,
            "policy_id": "",
            "interaction_id": trx["interaction_id"],
            "doc_type": "transcript",
            "title": f"{ct} — {name} ({disposition.title()}) on {inter.get('interaction_date', '')[:10]}",
            "content": content,
            "created_at": inter.get("interaction_date", ""),
        })

    return docs


# ── 4. Knowledge Base Articles ────────────────────────────────────────────────

def generate_knowledge_base():
    articles = [
        {
            "title": "Retention Call Procedure — Standard Operating Procedure",
            "content": (
                "RETENTION CALL PROCEDURE\n"
                "========================\n\n"
                "Purpose: Guide service representatives through retention calls for "
                "at-risk customers.\n\n"
                "STEP 1 — PREPARATION\n"
                "Review the customer's 360 profile before calling. Note:\n"
                "- Active policies and renewal dates\n"
                "- Recent interaction history and sentiment\n"
                "- Risk tier and contributing signals\n"
                "- NBA recommendation and confidence level\n\n"
                "STEP 2 — OPENING\n"
                "Acknowledge the customer by name. Reference their tenure. "
                "Express appreciation for their loyalty.\n\n"
                "STEP 3 — LISTEN AND ACKNOWLEDGE\n"
                "Ask open-ended questions about their experience. Listen actively. "
                "Acknowledge any frustrations without being defensive. Document "
                "key concerns.\n\n"
                "STEP 4 — OFFER SOLUTIONS\n"
                "Based on the customer's concerns and the NBA recommendation:\n"
                "- For premium concerns: Review discount eligibility, multi-policy "
                "bundles, deductible adjustments\n"
                "- For service complaints: Offer dedicated representative, escalate "
                "unresolved issues, provide direct contact\n"
                "- For coverage questions: Schedule a coverage review, explain "
                "current protections\n\n"
                "STEP 5 — CLOSE AND FOLLOW-UP\n"
                "Summarize actions taken. Set clear expectations for next steps. "
                "Schedule follow-up if needed. Log the interaction and decision "
                "in the system.\n\n"
                "IMPORTANT: All retention offers must be approved through the "
                "human review gate. Do not promise discounts without supervisor "
                "authorization.\n"
            ),
        },
        {
            "title": "Complaint Escalation Procedure",
            "content": (
                "COMPLAINT ESCALATION PROCEDURE\n"
                "===============================\n\n"
                "When to escalate:\n"
                "- Customer has called 3+ times about the same issue\n"
                "- Complaint involves a regulatory concern\n"
                "- Customer threatens to file a DOI complaint\n"
                "- Issue has been unresolved for more than 15 business days\n"
                "- Customer requests a supervisor\n\n"
                "ESCALATION LEVELS\n"
                "-----------------\n"
                "Level 1 — Senior Representative: Handle complex policy or billing "
                "disputes. Response within 24 hours.\n"
                "Level 2 — Team Supervisor: Handle unresolved Level 1 issues, "
                "authorization for retention offers >10%. Response within 4 hours.\n"
                "Level 3 — Department Manager: Handle regulatory threats, legal "
                "concerns, high-value customer retention. Response within 2 hours.\n\n"
                "DOCUMENTATION REQUIREMENTS\n"
                "- Log all escalation details in the interaction record\n"
                "- Include: original complaint date, number of prior contacts, "
                "customer sentiment, specific request, and resolution attempted\n"
                "- Attach evidence from the customer's 360 profile\n\n"
                "RESOLUTION TRACKING\n"
                "- All escalated complaints must be resolved within 5 business days\n"
                "- Send confirmation to customer when resolved\n"
                "- Log resolution in decision audit trail\n"
            ),
        },
        {
            "title": "Cross-Sell Eligibility Rules and Guidelines",
            "content": (
                "CROSS-SELL ELIGIBILITY RULES\n"
                "============================\n\n"
                "Eligible cross-sell opportunities are identified by the NBA engine "
                "based on customer profile analysis. Representatives should follow "
                "these guidelines:\n\n"
                "AUTO → HOME BUNDLE\n"
                "- Eligible if: customer has auto policy, no home policy, "
                "tenure > 1 year, payment history is good\n"
                "- Discount: 10-15% multi-policy discount on combined premium\n"
                "- Timing: Best during renewal window or after positive interaction\n\n"
                "HOME → UMBRELLA\n"
                "- Eligible if: customer has home policy with dwelling limit > $300K, "
                "no umbrella policy\n"
                "- Discount: 5% umbrella discount when bundled\n"
                "- Timing: During coverage review or after claim settlement\n\n"
                "AUTO → RENTERS (for non-homeowners)\n"
                "- Eligible if: customer has auto only, no home policy, "
                "address indicates rental\n"
                "- Discount: 8% bundle discount\n\n"
                "DO NOT CROSS-SELL WHEN:\n"
                "- Customer has open complaint (wait until resolved)\n"
                "- Risk tier is critical (focus on retention first)\n"
                "- Customer sentiment is negative in last 30 days\n"
                "- Customer has explicitly declined in last 6 months\n"
            ),
        },
        {
            "title": "Renewal Discount Policy and Authorization Matrix",
            "content": (
                "RENEWAL DISCOUNT POLICY\n"
                "=======================\n\n"
                "Purpose: Define authorized discount levels for policy renewals "
                "to support customer retention.\n\n"
                "STANDARD DISCOUNTS (no approval required):\n"
                "- Multi-policy bundle: 10-15% (auto-applied)\n"
                "- Claims-free 3+ years: 5%\n"
                "- Loyalty 5+ years: 3%\n"
                "- Paperless billing: 2%\n"
                "- Autopay enrollment: 2%\n\n"
                "RETENTION DISCOUNTS (supervisor approval required):\n"
                "- At-risk customer adjustment: up to 10%\n"
                "- Competitive match: up to 12% (requires competitor quote)\n"
                "- Win-back offer: up to 15% (lapsed customer returning)\n\n"
                "MAXIMUM COMBINED DISCOUNT: 25%\n\n"
                "AUTHORIZATION MATRIX:\n"
                "- Up to 10%: Service representative (standard discounts only)\n"
                "- 10-15%: Team supervisor approval\n"
                "- 15-20%: Department manager approval\n"
                "- 20-25%: VP approval (exceptional cases only)\n\n"
                "All discounts must be logged in the decision audit trail with "
                "justification and approver information.\n"
            ),
        },
        {
            "title": "Claim Filing and Processing Guide for Representatives",
            "content": (
                "CLAIM FILING AND PROCESSING GUIDE\n"
                "=================================\n\n"
                "STEP 1 — INTAKE\n"
                "Collect the following from the customer:\n"
                "- Policy number and customer ID\n"
                "- Date and time of loss\n"
                "- Description of the incident\n"
                "- Police report number (if applicable)\n"
                "- Photos or documentation (if available)\n"
                "- Contact information for other parties involved\n\n"
                "STEP 2 — VERIFICATION\n"
                "- Verify policy is active and covers the type of loss\n"
                "- Check deductible amount for applicable coverage\n"
                "- Confirm no duplicate claim exists\n"
                "- Review coverage limits\n\n"
                "STEP 3 — ASSIGNMENT\n"
                "- Auto claims < $5,000: Fast-track processing (5 business days)\n"
                "- Auto claims $5,000-$25,000: Standard adjuster assignment\n"
                "- Home claims: Field inspection required for damage > $2,000\n"
                "- All claims: Customer receives confirmation email within 24 hours\n\n"
                "STEP 4 — COMMUNICATION\n"
                "- Update customer within 3 business days of filing\n"
                "- Provide adjuster contact information\n"
                "- Set expectations for timeline\n"
                "- Document all communication in interaction log\n\n"
                "SLA TARGETS:\n"
                "- Acknowledgment: 24 hours\n"
                "- Initial assessment: 5 business days\n"
                "- Resolution (simple): 15 business days\n"
                "- Resolution (complex): 30 business days\n"
            ),
        },
        {
            "title": "Customer Risk Signal Definitions and Weights",
            "content": (
                "CUSTOMER RISK SIGNAL DEFINITIONS\n"
                "================================\n\n"
                "The Customer 360 platform uses 7 weighted signals to compute "
                "a composite risk score (0.0 to 1.0).\n\n"
                "1. RENEWAL PROXIMITY (weight: 0.20)\n"
                "   How close is the nearest policy renewal?\n"
                "   - Critical: <= 14 days\n"
                "   - High: 15-30 days\n"
                "   - Medium: 31-60 days\n"
                "   - Low: > 60 days\n\n"
                "2. NEGATIVE SENTIMENT (weight: 0.20)\n"
                "   Count of negative-sentiment interactions in last 90 days.\n"
                "   Derived from AI sentiment analysis of transcripts and emails.\n\n"
                "3. SENTIMENT TREND (weight: 0.15)\n"
                "   Direction of sentiment change: comparing current 90-day window "
                "to prior 90-day window.\n"
                "   - Worsening: score increasing\n"
                "   - Stable: no significant change\n"
                "   - Improving: score decreasing\n\n"
                "4. PAYMENT RISK (weight: 0.15)\n"
                "   Ratio of late + missed payments to total payments.\n"
                "   Higher ratio = higher risk.\n\n"
                "5. COMPLAINT ACTIVITY (weight: 0.10)\n"
                "   Number of complaint-disposition interactions in last 90 days.\n\n"
                "6. CLAIM ACTIVITY (weight: 0.10)\n"
                "   Number of open (unresolved) claims.\n\n"
                "7. ENGAGEMENT DROP (weight: 0.05)\n"
                "   Decline in interaction frequency compared to historical pattern.\n\n"
                "8. CROSS-SELL OPPORTUNITY (weight: 0.05)\n"
                "   Not a risk signal but a positive indicator. Reduces composite "
                "risk when customer has bundling potential.\n\n"
                "RISK TIERS:\n"
                "- Critical: >= 0.75\n"
                "- High: 0.50 - 0.74\n"
                "- Medium: 0.25 - 0.49\n"
                "- Low: < 0.25\n"
            ),
        },
        {
            "title": "Data Privacy and Customer Communication Policy",
            "content": (
                "DATA PRIVACY AND CUSTOMER COMMUNICATION POLICY\n"
                "================================================\n\n"
                "RECORDING CONSENT\n"
                "- All call recordings require explicit verbal consent\n"
                "- If consent is declined, the call proceeds without recording\n"
                "- Transcripts from non-consented calls are not processed for "
                "AI sentiment analysis\n"
                "- Consent status is logged per interaction\n\n"
                "EMAIL COMMUNICATION\n"
                "- Customer emails are retained for 7 years per regulatory requirement\n"
                "- Emails containing PII are stored in encrypted format\n"
                "- Automated email responses must include opt-out instructions\n\n"
                "AI-DERIVED INSIGHTS\n"
                "- AI sentiment scores are advisory, not deterministic\n"
                "- Representatives must not share raw AI scores with customers\n"
                "- Recommendations generated by the NBA engine require human approval\n"
                "- All AI-assisted decisions are logged in the decision audit trail\n\n"
                "CUSTOMER DATA ACCESS\n"
                "- Service representatives access customer data through the "
                "Customer 360 application only\n"
                "- Direct database access is restricted to data engineers\n"
                "- Auditors have read-only access to decision logs\n"
                "- All access is logged and auditable\n"
            ),
        },
    ]

    docs = []
    for i, article in enumerate(articles, 1):
        docs.append({
            "doc_id": f"DOC-KB-{i:06d}",
            "customer_id": "",
            "policy_id": "",
            "interaction_id": "",
            "doc_type": "knowledge_base",
            "title": article["title"],
            "content": article["content"],
            "created_at": "2026-01-01T00:00:00",
        })

    return docs


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Loading existing synthetic data...")
    customers = read_csv("customers.csv")
    policies = read_csv("policies.csv")
    coverages = read_csv("coverages.csv")
    interactions = read_csv("interactions.csv")
    transcripts = read_csv("transcripts.csv")

    print("Generating policy summary documents...")
    policy_docs = generate_policy_summaries(customers, policies, coverages)
    print(f"  {len(policy_docs)} policy summaries")

    print("Generating customer emails...")
    email_docs = generate_emails(customers, policies, interactions)
    print(f"  {len(email_docs)} emails")

    print("Generating transcript documents...")
    transcript_docs = generate_transcript_docs(transcripts, interactions, customers)
    print(f"  {len(transcript_docs)} transcripts")

    print("Generating knowledge base articles...")
    kb_docs = generate_knowledge_base()
    print(f"  {len(kb_docs)} knowledge base articles")

    all_docs = policy_docs + email_docs + transcript_docs + kb_docs
    print(f"\nTotal documents: {len(all_docs)}")

    fieldnames = [
        "doc_id", "customer_id", "policy_id", "interaction_id",
        "doc_type", "title", "content", "created_at",
    ]
    out_path = OUTPUT_DIR / "unstructured_documents.csv"
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(all_docs)

    print(f"\nOutput written to: {out_path}")
    print(f"Breakdown by doc_type:")
    from collections import Counter
    counts = Counter(d["doc_type"] for d in all_docs)
    for dt, ct in sorted(counts.items()):
        print(f"  {dt}: {ct}")


if __name__ == "__main__":
    main()
