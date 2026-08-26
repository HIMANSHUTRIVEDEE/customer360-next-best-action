"""
Comprehensive validation script for synthetic data in data/generated/.
Uses only Python standard library.
"""

import csv
import json
import hashlib
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

BASE_DIR = Path(__file__).parent
GENERATED_DIR = BASE_DIR / "generated"
EVIDENCE_DIR = BASE_DIR.parent / "evidence" / "development" / "day-2"

EXPECTED_FILES = [
    "customers.csv",
    "policies.csv",
    "coverages.csv",
    "claims.csv",
    "payments.csv",
    "interactions.csv",
    "transcripts.csv",
    "service_representatives.csv",
    "scenario_expectations.csv",
]

results = []


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def load_csv(filename):
    path = GENERATED_DIR / filename
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def add_result(check_id, check_name, status, detail=""):
    results.append({
        "check_id": check_id,
        "check_name": check_name,
        "status": status,
        "detail": detail,
    })


def check_unique(check_id, check_name, filename, pk_col):
    rows = load_csv(filename)
    vals = [r[pk_col] for r in rows]
    dupes = len(vals) - len(set(vals))
    if dupes == 0:
        add_result(check_id, check_name, "PASS")
    else:
        add_result(check_id, check_name, "FAIL", f"{dupes} duplicate values in {pk_col}")


def check_fk(check_id, check_name, child_file, child_col, parent_file, parent_col):
    children = load_csv(child_file)
    parents = load_csv(parent_file)
    parent_set = {r[parent_col] for r in parents}
    missing = [r[child_col] for r in children if r[child_col] and r[child_col] not in parent_set]
    if not missing:
        add_result(check_id, check_name, "PASS")
    else:
        add_result(check_id, check_name, "FAIL", f"{len(missing)} orphaned refs: {missing[:5]}")


def check_enum(check_id, check_name, filename, col, allowed):
    rows = load_csv(filename)
    vals = {r[col] for r in rows if r[col]}
    invalid = vals - set(allowed)
    if not invalid:
        add_result(check_id, check_name, "PASS")
    else:
        add_result(check_id, check_name, "FAIL", f"Invalid values: {invalid}")


# === Check 1: File Existence ===
def check_files_exist():
    manifest_path = GENERATED_DIR / "manifest.json"
    missing = []
    for f in EXPECTED_FILES:
        if not (GENERATED_DIR / f).exists():
            missing.append(f)
    if not manifest_path.exists():
        missing.append("manifest.json")
    if not missing:
        add_result(1, "check_files_exist", "PASS")
    else:
        add_result(1, "check_files_exist", "FAIL", f"Missing: {missing}")


# === Check 2: Manifest Integrity ===
def check_manifest_matches():
    manifest_path = GENERATED_DIR / "manifest.json"
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    errors = []
    manifest_files = {entry["filename"] for entry in manifest["files"]}
    actual_files = {f for f in EXPECTED_FILES if (GENERATED_DIR / f).exists()}
    if manifest_files != actual_files:
        errors.append(f"File mismatch: manifest={manifest_files}, actual={actual_files}")
    for entry in manifest["files"]:
        fp = GENERATED_DIR / entry["filename"]
        if fp.exists():
            actual_hash = sha256_file(fp)
            if actual_hash != entry["sha256"]:
                errors.append(f"{entry['filename']}: expected {entry['sha256'][:12]}... got {actual_hash[:12]}...")
    if not errors:
        add_result(2, "check_manifest_matches", "PASS")
    else:
        add_result(2, "check_manifest_matches", "FAIL", "; ".join(errors))


# === Checks 3-10: PK Uniqueness ===
def run_pk_checks():
    check_unique(3, "check_pk_customers", "customers.csv", "customer_id")
    check_unique(4, "check_pk_policies", "policies.csv", "policy_id")
    check_unique(5, "check_pk_coverages", "coverages.csv", "coverage_id")
    check_unique(6, "check_pk_claims", "claims.csv", "claim_id")
    check_unique(7, "check_pk_payments", "payments.csv", "payment_id")
    check_unique(8, "check_pk_interactions", "interactions.csv", "interaction_id")
    check_unique(9, "check_pk_transcripts", "transcripts.csv", "transcript_id")
    check_unique(10, "check_pk_service_reps", "service_representatives.csv", "representative_id")


# === Checks 11-20: FK Validity ===
def run_fk_checks():
    check_fk(11, "check_fk_policies_customers", "policies.csv", "customer_id", "customers.csv", "customer_id")
    check_fk(12, "check_fk_coverages_policies", "coverages.csv", "policy_id", "policies.csv", "policy_id")
    check_fk(13, "check_fk_claims_policies", "claims.csv", "policy_id", "policies.csv", "policy_id")
    check_fk(14, "check_fk_claims_customers", "claims.csv", "customer_id", "customers.csv", "customer_id")

    # Check 15: claims.customer_id matches the customer who owns claims.policy_id
    claims = load_csv("claims.csv")
    policies = load_csv("policies.csv")
    pol_owner = {r["policy_id"]: r["customer_id"] for r in policies}
    mismatches = []
    for c in claims:
        expected_owner = pol_owner.get(c["policy_id"])
        if expected_owner and expected_owner != c["customer_id"]:
            mismatches.append(c["claim_id"])
    if not mismatches:
        add_result(15, "check_fk_claims_ownership", "PASS")
    else:
        add_result(15, "check_fk_claims_ownership", "FAIL", f"{len(mismatches)} claims with mismatched owner: {mismatches[:5]}")

    check_fk(16, "check_fk_payments_customers", "payments.csv", "customer_id", "customers.csv", "customer_id")
    check_fk(17, "check_fk_payments_policies", "payments.csv", "policy_id", "policies.csv", "policy_id")
    check_fk(18, "check_fk_interactions_customers", "interactions.csv", "customer_id", "customers.csv", "customer_id")

    # Check 19: non-empty interactions.representative_id exists in service_representatives
    interactions = load_csv("interactions.csv")
    reps = load_csv("service_representatives.csv")
    rep_set = {r["representative_id"] for r in reps}
    missing = [i["interaction_id"] for i in interactions if i["representative_id"] and i["representative_id"] not in rep_set]
    if not missing:
        add_result(19, "check_fk_interactions_reps", "PASS")
    else:
        add_result(19, "check_fk_interactions_reps", "FAIL", f"{len(missing)} interactions with invalid rep_id")

    check_fk(20, "check_fk_transcripts_interactions", "transcripts.csv", "interaction_id", "interactions.csv", "interaction_id")


# === Checks 21-22: Cardinality ===
def run_cardinality_checks():
    # Check 21: transcript one per interaction
    transcripts = load_csv("transcripts.csv")
    int_ids = [t["interaction_id"] for t in transcripts]
    dupes = len(int_ids) - len(set(int_ids))
    if dupes == 0:
        add_result(21, "check_transcript_one_per_interaction", "PASS")
    else:
        add_result(21, "check_transcript_one_per_interaction", "FAIL", f"{dupes} duplicate interaction_ids in transcripts")

    # Check 22: active policies have coverage
    policies = load_csv("policies.csv")
    coverages = load_csv("coverages.csv")
    coverage_pols = {c["policy_id"] for c in coverages}
    active_no_cov = [p["policy_id"] for p in policies if p["status"] == "active" and p["policy_id"] not in coverage_pols]
    if not active_no_cov:
        add_result(22, "check_active_policies_have_coverage", "PASS")
    else:
        add_result(22, "check_active_policies_have_coverage", "FAIL", f"{len(active_no_cov)} active policies without coverage: {active_no_cov[:5]}")


# === Checks 23-35: Domain Rules ===
def run_domain_checks():
    # Check 23: policy dates
    policies = load_csv("policies.csv")
    bad_dates = [p["policy_id"] for p in policies if p["effective_date"] and p["expiration_date"] and p["effective_date"] >= p["expiration_date"]]
    if not bad_dates:
        add_result(23, "check_policy_dates", "PASS")
    else:
        add_result(23, "check_policy_dates", "FAIL", f"{len(bad_dates)} policies with effective >= expiration: {bad_dates[:5]}")

    # Check 24: payment amounts positive
    payments = load_csv("payments.csv")
    bad_amts = [p["payment_id"] for p in payments if p["amount"] and float(p["amount"]) <= 0]
    if not bad_amts:
        add_result(24, "check_payment_amounts_positive", "PASS")
    else:
        add_result(24, "check_payment_amounts_positive", "FAIL", f"{len(bad_amts)} payments with amount <= 0")

    # Enums
    check_enum(25, "check_enum_customer_status", "customers.csv", "status", ["active", "inactive", "prospect"])
    check_enum(26, "check_enum_product_type", "policies.csv", "product_type", ["auto", "home", "umbrella", "renters"])
    check_enum(27, "check_enum_policy_status", "policies.csv", "status", ["quoted", "bound", "active", "renewed", "lapsed", "cancelled"])
    check_enum(28, "check_enum_payment_frequency", "policies.csv", "payment_frequency", ["monthly", "quarterly", "semi_annual", "annual"])
    check_enum(29, "check_enum_payment_status", "payments.csv", "status", ["on_time", "late", "grace_period", "missed", "pending"])
    check_enum(30, "check_enum_claim_status", "claims.csv", "status", ["filed", "under_review", "settled", "denied", "withdrawn"])
    check_enum(31, "check_enum_channel", "interactions.csv", "channel", ["phone", "email", "chat"])
    check_enum(32, "check_enum_direction", "interactions.csv", "direction", ["inbound", "outbound", "internal_note"])
    check_enum(33, "check_enum_disposition", "interactions.csv", "disposition", ["inquiry", "complaint", "request", "notification", "general"])
    check_enum(34, "check_enum_content_type", "transcripts.csv", "content_type", ["call_transcript", "email_body", "agent_note"])
    check_enum(35, "check_enum_rep_role", "service_representatives.csv", "role", ["service_rep", "retention_specialist", "supervisor"])


# === Checks 36-37: Transcript Checks ===
def run_transcript_checks():
    transcripts = load_csv("transcripts.csv")

    # Check 36: consent flag populated
    empty_consent = [t["transcript_id"] for t in transcripts if t["recording_consent_flag"] not in ("TRUE", "FALSE")]
    if not empty_consent:
        add_result(36, "check_consent_flag_populated", "PASS")
    else:
        add_result(36, "check_consent_flag_populated", "FAIL", f"{len(empty_consent)} transcripts with empty/invalid consent flag")

    # Check 37: word_count matches actual
    mismatches = []
    for t in transcripts:
        actual_wc = len(t["raw_text"].split())
        reported_wc = int(t["word_count"])
        if abs(actual_wc - reported_wc) > 2:
            mismatches.append(f"{t['transcript_id']}: reported={reported_wc}, actual={actual_wc}")
    if not mismatches:
        add_result(37, "check_word_count_matches", "PASS")
    else:
        add_result(37, "check_word_count_matches", "FAIL", f"{len(mismatches)} mismatches: {mismatches[:3]}")


# === Checks 38-39: Scenario Coverage ===
def run_scenario_checks():
    customers = load_csv("customers.csv")
    cust_ids = {c["customer_id"] for c in customers}

    # Check 38: CUST-001 through CUST-012 exist
    expected = {f"CUST-{str(i).zfill(3)}" for i in range(1, 13)}
    missing = expected - cust_ids
    if not missing:
        add_result(38, "check_all_scenarios_represented", "PASS")
    else:
        add_result(38, "check_all_scenarios_represented", "FAIL", f"Missing scenario customers: {sorted(missing)}")

    # Check 39: Maria Chen golden demo
    policies = load_csv("policies.csv")
    interactions = load_csv("interactions.csv")
    transcripts = load_csv("transcripts.csv")

    errors = []
    maria = [c for c in customers if c["customer_id"] == "CUST-001"]
    if not maria:
        errors.append("CUST-001 not found")
    else:
        m = maria[0]
        if m["first_name"] != "Maria" or m["last_name"] != "Chen":
            errors.append(f"Name mismatch: {m['first_name']} {m['last_name']}")
        if m["household_id"] != "HH-001":
            errors.append(f"household_id={m['household_id']}, expected HH-001")

    maria_pols = [p for p in policies if p["customer_id"] == "CUST-001" and p["status"] == "active"]
    auto_active = [p for p in maria_pols if p["product_type"] == "auto"]
    home_active = [p for p in maria_pols if p["product_type"] == "home"]
    if len(auto_active) < 1:
        errors.append("No active auto policy")
    if len(home_active) < 1:
        errors.append("No active home policy")

    maria_ints = [i for i in interactions if i["customer_id"] == "CUST-001"]
    if len(maria_ints) < 4:
        errors.append(f"Only {len(maria_ints)} interactions, need >=4")

    maria_int_ids = {i["interaction_id"] for i in maria_ints}
    maria_transcripts = [t for t in transcripts if t["interaction_id"] in maria_int_ids]
    negative_words = {"frustrated", "unacceptable", "disappointed", "angry", "terrible", "horrible", "worst", "upset", "furious", "ridiculous", "annoyed", "dissatisfied", "nobody can explain", "went up", "not helpful", "unhappy", "poor", "concern", "issue", "problem"}
    neg_transcripts = [t for t in maria_transcripts if any(w in t["raw_text"].lower() for w in negative_words)]
    if len(neg_transcripts) < 2:
        errors.append(f"Only {len(neg_transcripts)} transcripts with negative tone, need >=2")

    non_consent = [t for t in maria_transcripts if t["recording_consent_flag"] != "TRUE"]
    if non_consent:
        errors.append(f"{len(non_consent)} Maria transcripts without consent=TRUE")

    if not errors:
        add_result(39, "check_maria_chen_golden_demo", "PASS")
    else:
        add_result(39, "check_maria_chen_golden_demo", "FAIL", "; ".join(errors))


# === Checks 40-42: Safety Checks ===
def run_safety_checks():
    # Check 40: no NBA or enrichment fields in headers
    forbidden_cols = {"sentiment_score", "sentiment_label", "enrichment_status", "risk_score", "recommendation", "action_type"}
    found = []
    for f in EXPECTED_FILES:
        path = GENERATED_DIR / f
        if path.exists():
            with open(path, newline="", encoding="utf-8") as fh:
                reader = csv.reader(fh)
                headers = next(reader, [])
                overlap = set(h.lower().strip() for h in headers) & forbidden_cols
                if overlap:
                    found.append(f"{f}: {overlap}")
    if not found:
        add_result(40, "check_no_nba_or_enrichment_fields", "PASS")
    else:
        add_result(40, "check_no_nba_or_enrichment_fields", "FAIL", "; ".join(found))

    # Check 41: no credential patterns
    cred_patterns = [
        r"password\s*=",
        r"api_key\s*=",
        r"secret\s*=",
        r"token\s*=",
        r"BEGIN PRIVATE KEY",
        r"AccountKey=",
        r"AKIA[0-9A-Z]{16}",
    ]
    cred_re = re.compile("|".join(cred_patterns), re.IGNORECASE)
    cred_found = []
    for f in EXPECTED_FILES:
        path = GENERATED_DIR / f
        if path.exists():
            content = path.read_text(encoding="utf-8")
            if cred_re.search(content):
                cred_found.append(f)
    manifest_path = GENERATED_DIR / "manifest.json"
    if manifest_path.exists():
        content = manifest_path.read_text(encoding="utf-8")
        if cred_re.search(content):
            cred_found.append("manifest.json")
    if not cred_found:
        add_result(41, "check_no_credential_patterns", "PASS")
    else:
        add_result(41, "check_no_credential_patterns", "FAIL", f"Credential patterns found in: {cred_found}")

    # Check 42: no real PII patterns
    pii_errors = []
    customers = load_csv("customers.csv")
    for c in customers:
        if c["email"] and not c["email"].endswith("@example.com"):
            pii_errors.append(f"Non-example email: {c['email']}")
            break
        if c["phone"] and not c["phone"].startswith("555-"):
            pii_errors.append(f"Non-555 phone: {c['phone']}")
            break
    # Check all files for SSN pattern
    ssn_re = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
    for f in EXPECTED_FILES:
        path = GENERATED_DIR / f
        if path.exists():
            content = path.read_text(encoding="utf-8")
            if ssn_re.search(content):
                pii_errors.append(f"SSN pattern found in {f}")
    if not pii_errors:
        add_result(42, "check_no_real_pii_patterns", "PASS")
    else:
        add_result(42, "check_no_real_pii_patterns", "FAIL", "; ".join(pii_errors[:5]))


# === Check 43: Reproducibility ===
def check_reproducibility():
    manifest_path = GENERATED_DIR / "manifest.json"
    with open(manifest_path, encoding="utf-8") as f:
        original_manifest = json.load(f)
    original_hashes = {entry["filename"]: entry["sha256"] for entry in original_manifest["files"]}

    # Re-run the generator
    generator = BASE_DIR / "generate_synthetic.py"
    try:
        result = subprocess.run(
            [sys.executable, str(generator)],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            add_result(43, "check_reproducibility", "FAIL", f"Generator failed: {result.stderr[:200]}")
            return
    except Exception as e:
        add_result(43, "check_reproducibility", "FAIL", f"Could not re-run generator: {e}")
        return

    # Compare hashes
    mismatches = []
    for filename, expected_hash in original_hashes.items():
        fp = GENERATED_DIR / filename
        if fp.exists():
            actual = sha256_file(fp)
            if actual != expected_hash:
                mismatches.append(filename)
        else:
            mismatches.append(f"{filename} (missing after re-gen)")

    if not mismatches:
        add_result(43, "check_reproducibility", "PASS")
    else:
        add_result(43, "check_reproducibility", "FAIL", f"Hash mismatch after re-run: {mismatches}")


# === Main ===
def main():
    print("Running synthetic data validation...")
    check_files_exist()
    check_manifest_matches()
    run_pk_checks()
    run_fk_checks()
    run_cardinality_checks()
    run_domain_checks()
    run_transcript_checks()
    run_scenario_checks()
    run_safety_checks()
    check_reproducibility()

    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")

    report = {
        "validation_timestamp": datetime.now().isoformat(),
        "total_checks": len(results),
        "passed": passed,
        "failed": failed,
        "results": results,
    }

    # Write JSON report
    json_path = GENERATED_DIR / "validation-report.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(f"JSON report: {json_path}")

    # Write markdown report
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    md_path = EVIDENCE_DIR / "validation-results.md"
    lines = [
        "# Synthetic Data Validation Results",
        "",
        f"**Timestamp:** {report['validation_timestamp']}",
        "",
        "| # | Check Name | Status | Detail |",
        "|---|-----------|--------|--------|",
    ]
    for r in results:
        detail = r["detail"].replace("|", "\\|") if r["detail"] else ""
        lines.append(f"| {r['check_id']} | {r['check_name']} | {r['status']} | {detail} |")
    lines.append("")
    lines.append(f"**{passed}/{len(results)} checks passed.**")
    if failed > 0:
        lines.append("")
        lines.append("## Failures")
        lines.append("")
        for r in results:
            if r["status"] == "FAIL":
                lines.append(f"- **{r['check_name']}**: {r['detail']}")
    lines.append("")

    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Markdown report: {md_path}")

    print(f"\nResult: {passed}/{len(results)} checks passed, {failed} failed.")
    if failed > 0:
        for r in results:
            if r["status"] == "FAIL":
                print(f"  FAIL [{r['check_id']}] {r['check_name']}: {r['detail']}")
        sys.exit(1)
    else:
        print("All checks passed!")


if __name__ == "__main__":
    main()
