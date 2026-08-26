"""
Deterministic synthetic data generator for Insurance Customer 360 prototype.
Seed: 42. All outputs reproducible across runs.
"""

import csv
import json
import hashlib
import random
import os
from datetime import date, datetime, timedelta
from pathlib import Path

# === Configuration ===
SEED = 42
GENERATOR_VERSION = "1.0.0"
TODAY = date.today()
NOW = datetime.now().replace(microsecond=0)
OUTPUT_DIR = Path(__file__).parent / "generated"

random.seed(SEED)

# === Helpers ===

def fmt_date(d):
    if d is None:
        return ""
    return d.strftime("%Y-%m-%d")

def fmt_ts(dt):
    if dt is None:
        return ""
    return dt.strftime("%Y-%m-%dT%H:%M:%S")

def fmt_bool(b):
    if b is None:
        return ""
    return "TRUE" if b else "FALSE"

def fmt_num(n):
    if n is None:
        return ""
    return f"{n:.2f}"

def fmt_int(n):
    if n is None:
        return ""
    return str(n)

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def write_csv(filename, rows, fieldnames):
    path = OUTPUT_DIR / filename
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return path

def days_ago(n):
    return TODAY - timedelta(days=n)

def ts_days_ago(n, hour=10, minute=30):
    d = days_ago(n)
    return datetime(d.year, d.month, d.day, hour, minute, 0)

def random_date_between(start, end):
    delta = (end - start).days
    if delta <= 0:
        return start
    return start + timedelta(days=random.randint(0, delta))

def random_ts_business_hours(d):
    hour = random.randint(8, 17)
    minute = random.randint(0, 59)
    return datetime(d.year, d.month, d.day, hour, minute, 0)

# === Name pools (no protected characteristics) ===
FIRST_NAMES = [
    "Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Quinn", "Avery",
    "Parker", "Skyler", "Dakota", "Reese", "Cameron", "Drew", "Finley", "Hayden",
    "Jamie", "Logan", "Peyton", "Rowan", "Sage", "Blake", "Ellis", "Harper",
    "Kendall", "Lane", "Micah", "Oakley", "Robin", "Spencer", "Tatum", "Val",
    "Wren", "Adrian", "Briar", "Cedar", "Devon", "Emery", "Francis", "Glenn",
    "Holly", "Indigo", "Jules", "Kerry", "Lee", "Marlow", "Noel", "Orion",
    "Pat", "Ray", "Sam", "Terry", "Uri", "Vic", "Winter", "Yael"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Martinez", "Anderson", "Taylor", "Thomas", "Jackson", "White", "Harris",
    "Thompson", "Robinson", "Clark", "Lewis", "Walker", "Hall", "Allen", "Young",
    "King", "Wright", "Scott", "Green", "Baker", "Adams", "Nelson", "Carter",
    "Mitchell", "Perez", "Roberts", "Turner", "Phillips", "Campbell", "Parker",
    "Evans", "Edwards", "Collins", "Stewart", "Morris", "Reed", "Morgan", "Bell",
    "Murphy", "Bailey", "Rivera", "Cooper", "Richardson", "Cox", "Howard", "Ward"
]

CITIES = [
    ("Springfield", "IL", "62701"), ("Portland", "OR", "97201"), ("Austin", "TX", "78701"),
    ("Denver", "CO", "80201"), ("Seattle", "WA", "98101"), ("Boston", "MA", "02101"),
    ("Phoenix", "AZ", "85001"), ("Nashville", "TN", "37201"), ("Columbus", "OH", "43201"),
    ("Charlotte", "NC", "28201"), ("Minneapolis", "MN", "55401"), ("Raleigh", "NC", "27601"),
    ("Tampa", "FL", "33601"), ("Cleveland", "OH", "44101"), ("Pittsburgh", "PA", "15201"),
    ("Cincinnati", "OH", "45201"), ("Kansas City", "MO", "64101"), ("Indianapolis", "IN", "46201"),
    ("San Diego", "CA", "92101"), ("Salt Lake City", "UT", "84101")
]

STREETS = [
    "123 Main St", "456 Oak Ave", "789 Elm Dr", "321 Pine Rd", "654 Maple Ln",
    "987 Cedar Ct", "147 Birch Way", "258 Walnut Blvd", "369 Spruce Pl", "471 Ash St",
    "582 Willow Ave", "693 Poplar Dr", "804 Cherry Rd", "915 Hickory Ln", "126 Sycamore Ct",
    "237 Juniper Way", "348 Magnolia Blvd", "459 Chestnut Pl", "561 Hawthorn St", "672 Laurel Ave"
]

# === Transcript templates ===
NEGATIVE_TRANSCRIPTS = [
    "I am really frustrated with the service I have been receiving. I called three times last week and nobody returned my call. My claim was supposed to be resolved weeks ago but I still have not heard anything. This is unacceptable for a customer who has been with you for years. I expected much better communication from your company.",
    "I am calling because my premium went up again and nobody can explain why. I have had no claims and my driving record is clean. When I asked the last representative they could not give me a clear answer either. I am starting to feel like I am not valued as a customer here. I need someone to actually look into this and give me a real explanation.",
    "This is the third time I have had to call about the same issue. The previous representative told me it would be resolved within five business days and that was three weeks ago. I am very disappointed with how this has been handled. I should not have to keep following up on something that should have been straightforward. Please escalate this to someone who can actually help.",
    "I filed my claim over a month ago and I still have not received any update on the status. Every time I call I get a different answer from a different person. Nobody seems to know what is going on with my file. I am losing patience with this process. I need this resolved immediately or I will have to consider other options.",
    "I received my renewal notice and the premium increase is shocking. Nobody warned me about this kind of increase. I have been a loyal customer for five years with no claims and this is how I am treated. I want to speak with someone who has the authority to do something about this. The current situation is simply not acceptable.",
]

POSITIVE_TRANSCRIPTS = [
    "Thank you so much for helping me with my coverage question today. The representative was very knowledgeable and explained everything clearly. I feel much more confident about my policy now. I appreciate the quick and thorough response to my inquiry.",
    "I just wanted to call and say how pleased I am with the service I received last week. My claim was handled efficiently and the communication throughout the process was excellent. Everything was resolved faster than I expected. Thank you for making it so easy.",
    "Everything looks good with my policy and I appreciate you taking the time to walk me through the details. I have been a customer for several years now and the service has always been reliable. Thank you for confirming my coverage amounts and answering my questions.",
    "I called to update my address and the process was so smooth. The representative was friendly and took care of everything in just a few minutes. I also appreciate being informed about the coverage review option. Great experience overall.",
    "I appreciate the proactive call about my upcoming renewal. It is nice to know that someone is looking out for my account. The rate looks reasonable and I am happy to continue my coverage. Thank you for the excellent customer service.",
]

NEUTRAL_TRANSCRIPTS = [
    "I am calling to check on the status of my policy renewal. I received a notice in the mail and wanted to confirm the dates and the premium amount. Can you also verify what coverages are currently included in my policy. I just want to make sure everything is in order before the renewal date.",
    "I would like to know what my current deductible is and whether there are any options to adjust it. I am not looking to make any changes right now but I want to understand my options for the future. Can you also tell me when my next payment is due.",
    "I need to update my mailing address on file. I recently moved and want to make sure all my correspondence goes to the right place. Can you also confirm that my auto policy is still active and when it expires. I believe it should be coming up in a few months.",
]

# === 1. Service Representatives ===
def generate_service_representatives():
    reps = [
        {"representative_id": "REP-001", "name": "Sarah Mitchell", "role": "service_rep", "active": "TRUE", "team": "Team Alpha"},
        {"representative_id": "REP-002", "name": "David Park", "role": "service_rep", "active": "TRUE", "team": "Team Alpha"},
        {"representative_id": "REP-003", "name": "Lisa Kumar", "role": "service_rep", "active": "TRUE", "team": "Team Beta"},
        {"representative_id": "REP-004", "name": "Robert Chen", "role": "retention_specialist", "active": "TRUE", "team": "Retention"},
        {"representative_id": "REP-005", "name": "Angela Torres", "role": "supervisor", "active": "FALSE", "team": ""},
    ]
    return reps

# === 2. Customers ===
def generate_customers():
    customers = []

    # Scenario customers
    scenario_customers = [
        {"customer_id": "CUST-001", "household_id": "HH-001", "first_name": "Maria", "last_name": "Chen",
         "customer_since": fmt_date(days_ago(3*365+100)), "status": "active",
         "date_of_birth": fmt_date(date(1982, 5, 15)), "email": "maria.chen@example.com", "phone": "555-0101",
         "address_line_1": "742 Evergreen Terrace", "city": "Springfield", "state": "IL", "postal_code": "62704"},
        {"customer_id": "CUST-002", "household_id": "HH-002", "first_name": "James", "last_name": "Rodriguez",
         "customer_since": fmt_date(days_ago(2*365+200)), "status": "active",
         "date_of_birth": fmt_date(date(1975, 11, 22)), "email": "james.rodriguez@example.com", "phone": "555-0102",
         "address_line_1": "456 Oak Ave", "city": "Austin", "state": "TX", "postal_code": "78702"},
        {"customer_id": "CUST-003", "household_id": "HH-003", "first_name": "Patricia", "last_name": "Williams",
         "customer_since": fmt_date(days_ago(5*365+50)), "status": "active",
         "date_of_birth": fmt_date(date(1968, 3, 8)), "email": "patricia.williams@example.com", "phone": "555-0103",
         "address_line_1": "789 Elm Dr", "city": "Portland", "state": "OR", "postal_code": "97202"},
        {"customer_id": "CUST-004", "household_id": "HH-004", "first_name": "Robert", "last_name": "Thompson",
         "customer_since": fmt_date(days_ago(3*365)), "status": "active",
         "date_of_birth": fmt_date(date(1980, 7, 30)), "email": "robert.thompson@example.com", "phone": "555-0104",
         "address_line_1": "321 Pine Rd", "city": "Denver", "state": "CO", "postal_code": "80202"},
        {"customer_id": "CUST-005", "household_id": "HH-005", "first_name": "Linda", "last_name": "Martinez",
         "customer_since": fmt_date(days_ago(4*365+100)), "status": "active",
         "date_of_birth": fmt_date(date(1972, 9, 12)), "email": "linda.martinez@example.com", "phone": "555-0105",
         "address_line_1": "654 Maple Ln", "city": "Seattle", "state": "WA", "postal_code": "98102"},
        {"customer_id": "CUST-006", "household_id": "HH-006", "first_name": "Michael", "last_name": "Davis",
         "customer_since": fmt_date(days_ago(2*365+50)), "status": "active",
         "date_of_birth": fmt_date(date(1985, 1, 25)), "email": "michael.davis@example.com", "phone": "555-0106",
         "address_line_1": "987 Cedar Ct", "city": "Boston", "state": "MA", "postal_code": "02102"},
        {"customer_id": "CUST-007", "household_id": "HH-007", "first_name": "Jennifer", "last_name": "Garcia",
         "customer_since": fmt_date(days_ago(3*365+200)), "status": "active",
         "date_of_birth": fmt_date(date(1979, 6, 18)), "email": "jennifer.garcia@example.com", "phone": "555-0107",
         "address_line_1": "147 Birch Way", "city": "Phoenix", "state": "AZ", "postal_code": "85002"},
        {"customer_id": "CUST-008", "household_id": "HH-008", "first_name": "William", "last_name": "Anderson",
         "customer_since": fmt_date(days_ago(2*365)), "status": "active",
         "date_of_birth": fmt_date(date(1990, 4, 5)), "email": "william.anderson@example.com", "phone": "555-0108",
         "address_line_1": "258 Walnut Blvd", "city": "Nashville", "state": "TN", "postal_code": "37202"},
        {"customer_id": "CUST-009", "household_id": "HH-009", "first_name": "Elizabeth", "last_name": "Taylor",
         "customer_since": fmt_date(days_ago(3*365+50)), "status": "active",
         "date_of_birth": fmt_date(date(1977, 12, 1)), "email": "elizabeth.taylor@example.com", "phone": "555-0109",
         "address_line_1": "369 Spruce Pl", "city": "Columbus", "state": "OH", "postal_code": "43202"},
        {"customer_id": "CUST-010", "household_id": "HH-010", "first_name": "Daniel", "last_name": "Moore",
         "customer_since": fmt_date(days_ago(365+30)), "status": "active",
         "date_of_birth": fmt_date(date(1995, 8, 20)), "email": "daniel.moore@example.com", "phone": "555-0110",
         "address_line_1": "471 Ash St", "city": "Charlotte", "state": "NC", "postal_code": "28202"},
        {"customer_id": "CUST-011", "household_id": "HH-011", "first_name": "Richard", "last_name": "Wilson",
         "customer_since": fmt_date(days_ago(6*365)), "status": "active",
         "date_of_birth": fmt_date(date(1970, 2, 14)), "email": "richard.wilson@example.com", "phone": "555-0111",
         "address_line_1": "582 Willow Ave", "city": "Minneapolis", "state": "MN", "postal_code": "55402"},
        {"customer_id": "CUST-011B", "household_id": "HH-011", "first_name": "Susan", "last_name": "Wilson",
         "customer_since": fmt_date(days_ago(6*365)), "status": "active",
         "date_of_birth": fmt_date(date(1972, 10, 3)), "email": "susan.wilson@example.com", "phone": "555-0112",
         "address_line_1": "582 Willow Ave", "city": "Minneapolis", "state": "MN", "postal_code": "55402"},
        {"customer_id": "CUST-012", "household_id": "HH-012", "first_name": "Thomas", "last_name": "Clark",
         "customer_since": fmt_date(days_ago(8*365+100)), "status": "active",
         "date_of_birth": fmt_date(date(1965, 4, 28)), "email": "thomas.clark@example.com", "phone": "555-0113",
         "address_line_1": "693 Poplar Dr", "city": "Raleigh", "state": "NC", "postal_code": "27602"},
    ]
    customers.extend(scenario_customers)

    # Background customers (~87 to reach ~100 total)
    rng = random.Random(SEED + 1000)
    for i in range(87):
        cid = f"CUST-{i+13:04d}"
        hh_id = f"HH-{i+13:03d}"
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        city, state, postal = rng.choice(CITIES)
        street = rng.choice(STREETS)
        years_customer = rng.randint(1, 15)
        cust_since = days_ago(years_customer * 365 + rng.randint(0, 364))
        status = "active" if rng.random() < 0.95 else "inactive"

        dob = ""
        if rng.random() > 0.20:
            age = rng.randint(18, 80)
            dob = fmt_date(date(TODAY.year - age, rng.randint(1, 12), rng.randint(1, 28)))

        email = ""
        if rng.random() > 0.05:
            email = f"{first.lower()}.{last.lower()}{i}@example.com"

        phone = ""
        if rng.random() > 0.05:
            phone = f"555-{rng.randint(1000, 9999)}"

        customers.append({
            "customer_id": cid,
            "household_id": hh_id,
            "first_name": first,
            "last_name": last,
            "customer_since": fmt_date(cust_since),
            "status": status,
            "date_of_birth": dob,
            "email": email,
            "phone": phone,
            "address_line_1": street,
            "city": city,
            "state": state,
            "postal_code": postal,
        })

    return customers

# === 3. Policies ===
def generate_policies(customers):
    policies = []
    policy_counter = [1]  # mutable counter

    def make_policy(customer_id, product_type, status, eff_date, exp_date, premium, freq, bound=None):
        pid = f"POL-{policy_counter[0]:06d}"
        policy_counter[0] += 1
        p = {
            "policy_id": pid,
            "customer_id": customer_id,
            "product_type": product_type,
            "status": status,
            "effective_date": fmt_date(eff_date),
            "expiration_date": fmt_date(exp_date),
            "premium_amount": fmt_num(premium),
            "payment_frequency": freq,
            "bound_date": fmt_date(bound) if bound else fmt_date(eff_date - timedelta(days=5)),
        }
        return p

    # SCN-001: Maria Chen - 2 policies (auto 16 days, home 7 months)
    policies.append(make_policy("CUST-001", "auto", "active",
                                days_ago(349), TODAY + timedelta(days=16), 1200.00, "monthly"))
    policies.append(make_policy("CUST-001", "home", "active",
                                days_ago(180), TODAY + timedelta(days=210), 1800.00, "monthly"))

    # SCN-002: James Rodriguez - 1 auto (22 days)
    policies.append(make_policy("CUST-002", "auto", "active",
                                days_ago(343), TODAY + timedelta(days=22), 1350.00, "monthly"))

    # SCN-003: Patricia Williams - 2 policies (auto 12 days, home active)
    policies.append(make_policy("CUST-003", "auto", "active",
                                days_ago(353), TODAY + timedelta(days=12), 1100.00, "monthly"))
    policies.append(make_policy("CUST-003", "home", "active",
                                days_ago(200), TODAY + timedelta(days=165), 1650.00, "quarterly"))

    # SCN-004: Robert Thompson - 1 auto (130 days out)
    policies.append(make_policy("CUST-004", "auto", "active",
                                days_ago(235), TODAY + timedelta(days=130), 1400.00, "monthly"))

    # SCN-005: Linda Martinez - 1 home (20 days)
    policies.append(make_policy("CUST-005", "home", "active",
                                days_ago(345), TODAY + timedelta(days=20), 1900.00, "monthly"))

    # SCN-006: Michael Davis - 1 auto (25 days)
    policies.append(make_policy("CUST-006", "auto", "active",
                                days_ago(340), TODAY + timedelta(days=25), 1250.00, "monthly"))

    # SCN-007: Jennifer Garcia - 1 home (15 days)
    policies.append(make_policy("CUST-007", "home", "active",
                                days_ago(350), TODAY + timedelta(days=15), 2100.00, "monthly"))

    # SCN-008: William Anderson - 1 auto (45 days), monthly
    policies.append(make_policy("CUST-008", "auto", "active",
                                days_ago(320), TODAY + timedelta(days=45), 1500.00, "monthly"))

    # SCN-009: Elizabeth Taylor - 1 home (22 days)
    policies.append(make_policy("CUST-009", "home", "active",
                                days_ago(343), TODAY + timedelta(days=22), 1750.00, "monthly"))

    # SCN-010: Daniel Moore - 1 renters (60 days)
    policies.append(make_policy("CUST-010", "renters", "active",
                                days_ago(305), TODAY + timedelta(days=60), 480.00, "monthly"))

    # SCN-011: Richard Wilson - 3 policies (auto 28 days, home, umbrella)
    policies.append(make_policy("CUST-011", "auto", "active",
                                days_ago(337), TODAY + timedelta(days=28), 1300.00, "monthly"))
    policies.append(make_policy("CUST-011", "home", "active",
                                days_ago(200), TODAY + timedelta(days=165), 2200.00, "quarterly"))
    policies.append(make_policy("CUST-011", "umbrella", "active",
                                days_ago(365), TODAY + timedelta(days=0) + timedelta(days=100), 500.00, "annual"))
    # SCN-011: Susan Wilson - 1 auto
    policies.append(make_policy("CUST-011B", "auto", "active",
                                days_ago(330), TODAY + timedelta(days=35), 1150.00, "monthly"))

    # SCN-012: Thomas Clark - 2 policies (auto 12 days, home)
    policies.append(make_policy("CUST-012", "auto", "active",
                                days_ago(353), TODAY + timedelta(days=12), 1050.00, "monthly"))
    policies.append(make_policy("CUST-012", "home", "active",
                                days_ago(180), TODAY + timedelta(days=185), 1950.00, "quarterly"))

    scenario_policy_count = len(policies)

    # Background policies
    rng = random.Random(SEED + 2000)
    bg_customers = [c for c in customers if c["customer_id"].startswith("CUST-0") and len(c["customer_id"]) > 8]
    product_weights = ["auto"] * 40 + ["home"] * 35 + ["renters"] * 15 + ["umbrella"] * 10
    freq_options = ["monthly"] * 60 + ["quarterly"] * 20 + ["semi_annual"] * 10 + ["annual"] * 10
    status_options = ["active"] * 80 + ["renewed"] * 10 + ["lapsed"] * 5 + ["cancelled"] * 5

    target_bg = 250 - scenario_policy_count
    for cust in bg_customers:
        num_policies = rng.randint(1, 4)
        for _ in range(num_policies):
            if len(policies) >= 250:
                break
            prod = rng.choice(product_weights)
            freq = rng.choice(freq_options)
            status = rng.choice(status_options)
            years_back = rng.uniform(0.5, 3.0)
            eff = days_ago(int(years_back * 365))
            exp = eff + timedelta(days=365)
            if status == "active" and exp < TODAY:
                exp = TODAY + timedelta(days=rng.randint(10, 300))
            premium = {
                "auto": rng.uniform(800, 2000),
                "home": rng.uniform(1200, 3000),
                "renters": rng.uniform(300, 700),
                "umbrella": rng.uniform(300, 800),
            }[prod]
            policies.append(make_policy(cust["customer_id"], prod, status, eff, exp, round(premium, 2), freq))
        if len(policies) >= 250:
            break

    return policies

# === 4. Coverages ===
def generate_coverages(policies):
    coverages = []
    cov_counter = [1]
    rng = random.Random(SEED + 3000)

    coverage_map = {
        "auto": ["liability", "collision", "comprehensive", "uninsured_motorist", "medical_payments"],
        "home": ["dwelling", "personal_property", "liability", "medical_payments"],
        "renters": ["personal_property", "liability", "medical_payments"],
        "umbrella": ["umbrella_excess"],
    }

    limit_ranges = {
        "liability": (100000, 500000),
        "collision": (25000, 75000),
        "comprehensive": (25000, 75000),
        "uninsured_motorist": (50000, 250000),
        "medical_payments": (5000, 25000),
        "dwelling": (200000, 750000),
        "personal_property": (50000, 200000),
        "umbrella_excess": (1000000, 5000000),
    }

    deductible_ranges = {
        "liability": (0, 0),
        "collision": (500, 2000),
        "comprehensive": (250, 1000),
        "uninsured_motorist": (0, 500),
        "medical_payments": (0, 250),
        "dwelling": (1000, 5000),
        "personal_property": (500, 2500),
        "umbrella_excess": (0, 0),
    }

    for pol in policies:
        prod = pol["product_type"]
        available = coverage_map[prod]
        if prod == "auto":
            n = rng.randint(2, 3)
        elif prod == "home":
            n = rng.randint(2, 3)
        elif prod == "renters":
            n = rng.randint(2, 2)
        else:
            n = 1
        chosen = available[:n]
        for cov_type in chosen:
            lo, hi = limit_ranges[cov_type]
            limit_amt = round(rng.randint(lo // 1000, hi // 1000) * 1000, 2)
            dlo, dhi = deductible_ranges[cov_type]
            deductible = round(rng.randint(dlo // 100 if dlo > 0 else 0, dhi // 100 if dhi > 0 else 0) * 100, 2) if dhi > 0 else 0.0
            coverages.append({
                "coverage_id": f"COV-{cov_counter[0]:06d}",
                "policy_id": pol["policy_id"],
                "coverage_type": cov_type,
                "limit_amount": fmt_num(limit_amt),
                "deductible_amount": fmt_num(deductible),
            })
            cov_counter[0] += 1

    return coverages

# === 5. Claims ===
def generate_claims(policies, customers):
    claims = []
    claim_counter = [1]
    rng = random.Random(SEED + 4000)

    def make_claim(policy_id, customer_id, filed, status, loss_date, loss_type, reserve=None, paid=None, closed=None):
        c = {
            "claim_id": f"CLM-{claim_counter[0]:06d}",
            "policy_id": policy_id,
            "customer_id": customer_id,
            "filed_date": fmt_date(filed),
            "status": status,
            "loss_date": fmt_date(loss_date),
            "loss_type": loss_type,
            "reserve_amount": fmt_num(reserve) if reserve else "",
            "paid_amount": fmt_num(paid) if paid else "",
            "closed_date": fmt_date(closed) if closed else "",
        }
        claim_counter[0] += 1
        return c

    # SCN-001: 1 settled claim on auto, 7 months old
    claims.append(make_claim("POL-000001", "CUST-001",
                             days_ago(210), "settled", days_ago(212), "collision",
                             reserve=5000.00, paid=4200.00, closed=days_ago(180)))

    # SCN-002: 1 open claim (under_review), filed 30 days ago
    claims.append(make_claim("POL-000003", "CUST-002",
                             days_ago(30), "under_review", days_ago(32), "collision",
                             reserve=8000.00))

    # Background claims
    loss_types = ["collision", "water_damage", "theft", "liability", "wind_damage", "fire", "vandalism"]
    statuses = ["settled"] * 15 + ["denied"] * 3 + ["filed"] * 2 + ["under_review"] * 3 + ["withdrawn"] * 2

    bg_policies = [p for p in policies if len(p["customer_id"]) > 8 or p["customer_id"] >= "CUST-013"]
    # Filter to active/renewed policies for claims
    claimable = [p for p in bg_policies if p["status"] in ("active", "renewed")]
    rng.shuffle(claimable)

    for pol in claimable[:28]:  # ~28 more background claims to reach ~30
        status = rng.choice(statuses)
        loss_date = random_date_between(days_ago(365), days_ago(30))
        filed = loss_date + timedelta(days=rng.randint(0, 3))
        loss_type = rng.choice(loss_types)
        reserve = round(rng.uniform(1000, 20000), 2) if status != "filed" else None
        paid = round(rng.uniform(500, reserve if reserve else 10000), 2) if status == "settled" else None
        closed = filed + timedelta(days=rng.randint(14, 90)) if status in ("settled", "denied", "withdrawn") else None

        claims.append(make_claim(pol["policy_id"], pol["customer_id"],
                                 filed, status, loss_date, loss_type, reserve, paid, closed))

    return claims

# === 6. Payments ===
def generate_payments(policies, customers):
    payments = []
    pay_counter = [1]
    rng = random.Random(SEED + 5000)

    def make_payment(customer_id, policy_id, due_date, amount, status, paid_date=None, amount_paid=None):
        p = {
            "payment_id": f"PAY-{pay_counter[0]:08d}",
            "customer_id": customer_id,
            "policy_id": policy_id,
            "due_date": fmt_date(due_date),
            "amount": fmt_num(amount),
            "status": status,
            "paid_date": fmt_date(paid_date) if paid_date else "",
            "amount_paid": fmt_num(amount_paid) if amount_paid else "",
        }
        pay_counter[0] += 1
        return p

    def get_period_months(freq):
        return {"monthly": 1, "quarterly": 3, "semi_annual": 6, "annual": 12}[freq]

    def get_period_amount(premium, freq):
        periods = {"monthly": 12, "quarterly": 4, "semi_annual": 2, "annual": 1}[freq]
        return round(premium / periods, 2)

    # Helper: generate payment history for a policy
    def gen_payments_for_policy(customer_id, policy_id, premium, freq, late_pattern=None, num_periods=6, is_background=False):
        """late_pattern: list of (index, status) tuples for specific payment statuses"""
        period_months = get_period_months(freq)
        amount = get_period_amount(premium, freq)
        if is_background:
            num_periods = min(3, 12 // period_months)
        actual_periods = min(num_periods, 12 // period_months)  # cap at 1 year

        result = []
        for i in range(actual_periods):
            due = days_ago((actual_periods - i) * period_months * 30)
            status = "on_time"
            paid_date = due - timedelta(days=rng.randint(0, 3))
            amount_paid = amount

            if late_pattern:
                for idx, st in late_pattern:
                    if i == idx:
                        status = st
                        if st == "late":
                            paid_date = due + timedelta(days=rng.randint(5, 15))
                        elif st == "grace_period":
                            paid_date = due + timedelta(days=rng.randint(1, 10))
                        elif st == "missed":
                            paid_date = None
                            amount_paid = None
                        elif st == "pending":
                            paid_date = None
                            amount_paid = None
                        break

            result.append(make_payment(customer_id, policy_id, due, amount, status, paid_date, amount_paid))
        return result

    # SCN-001: All on-time for both policies
    payments.extend(gen_payments_for_policy("CUST-001", "POL-000001", 1200.00, "monthly"))
    payments.extend(gen_payments_for_policy("CUST-001", "POL-000002", 1800.00, "monthly"))

    # SCN-002: Mostly on-time; 1 late payment 4 months ago (index 2 of 6 = ~4 months back)
    payments.extend(gen_payments_for_policy("CUST-002", "POL-000003", 1350.00, "monthly",
                                           late_pattern=[(2, "late")]))

    # SCN-003: All on-time
    payments.extend(gen_payments_for_policy("CUST-003", "POL-000004", 1100.00, "monthly"))
    payments.extend(gen_payments_for_policy("CUST-003", "POL-000005", 1650.00, "quarterly"))

    # SCN-004: On-time
    payments.extend(gen_payments_for_policy("CUST-004", "POL-000006", 1400.00, "monthly"))

    # SCN-005: On-time
    payments.extend(gen_payments_for_policy("CUST-005", "POL-000007", 1900.00, "monthly"))

    # SCN-006: On-time
    payments.extend(gen_payments_for_policy("CUST-006", "POL-000008", 1250.00, "monthly"))

    # SCN-007: On-time
    payments.extend(gen_payments_for_policy("CUST-007", "POL-000009", 2100.00, "monthly"))

    # SCN-008: 3 late + 1 grace_period (positions: late at 1,3,4 and grace at 5)
    payments.extend(gen_payments_for_policy("CUST-008", "POL-000010", 1500.00, "monthly",
                                           late_pattern=[(1, "late"), (3, "late"), (4, "late"), (5, "grace_period")]))

    # SCN-009: On-time
    payments.extend(gen_payments_for_policy("CUST-009", "POL-000011", 1750.00, "monthly"))

    # SCN-010: On-time
    payments.extend(gen_payments_for_policy("CUST-010", "POL-000012", 480.00, "monthly"))

    # SCN-011: All on-time across all 4 policies
    payments.extend(gen_payments_for_policy("CUST-011", "POL-000013", 1300.00, "monthly"))
    payments.extend(gen_payments_for_policy("CUST-011", "POL-000014", 2200.00, "quarterly"))
    payments.extend(gen_payments_for_policy("CUST-011", "POL-000015", 500.00, "annual"))
    payments.extend(gen_payments_for_policy("CUST-011B", "POL-000016", 1150.00, "monthly"))

    # SCN-012: 2 late in last 6 months (positions 2 and 4)
    payments.extend(gen_payments_for_policy("CUST-012", "POL-000017", 1050.00, "monthly",
                                           late_pattern=[(2, "late"), (4, "late")]))
    payments.extend(gen_payments_for_policy("CUST-012", "POL-000018", 1950.00, "quarterly"))

    # Background payments
    bg_policies = [p for p in policies if p["policy_id"] not in
                   {pp["policy_id"] for pp in policies[:18]}]  # skip scenario policies

    # Actually let's just do policies starting from POL-000019
    scenario_pids = set(f"POL-{i:06d}" for i in range(1, 19))
    for pol in policies:
        if pol["policy_id"] in scenario_pids:
            continue
        if pol["status"] not in ("active", "renewed"):
            continue
        premium = float(pol["premium_amount"])
        freq = pol["payment_frequency"]
        # ~8% late rate for background
        late_pattern = None
        if rng.random() < 0.08:
            late_idx = rng.randint(0, 5)
            late_pattern = [(late_idx, "late")]

        payments.extend(gen_payments_for_policy(pol["customer_id"], pol["policy_id"],
                                               premium, freq, late_pattern, is_background=True))

    return payments

# === 7. Interactions ===
def generate_interactions(customers, reps):
    interactions = []
    int_counter = [1]
    rng = random.Random(SEED + 6000)
    active_reps = [r["representative_id"] for r in reps if r["active"] == "TRUE" and r["role"] == "service_rep"]

    def make_interaction(customer_id, channel, direction, disposition, dt, duration=None, rep_id=None):
        i = {
            "interaction_id": f"INT-{int_counter[0]:06d}",
            "customer_id": customer_id,
            "channel": channel,
            "direction": direction,
            "disposition": disposition,
            "interaction_date": fmt_ts(dt),
            "duration_seconds": fmt_int(duration) if channel == "phone" and duration else "",
            "representative_id": rep_id if rep_id else rng.choice(active_reps),
        }
        int_counter[0] += 1
        return i

    # SCN-001: 4 interactions (2 recent negative, 2 older positive)
    interactions.append(make_interaction("CUST-001", "phone", "inbound", "complaint",
                                        ts_days_ago(45, 14, 20), duration=480, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-001", "email", "inbound", "inquiry",
                                        ts_days_ago(20, 9, 15), rep_id="REP-002"))
    interactions.append(make_interaction("CUST-001", "phone", "inbound", "general",
                                        ts_days_ago(220, 10, 30), duration=300, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-001", "phone", "inbound", "general",
                                        ts_days_ago(280, 11, 0), duration=240, rep_id="REP-003"))

    # SCN-002: 3 interactions in 90 days (2 negative, 1 neutral)
    interactions.append(make_interaction("CUST-002", "phone", "inbound", "complaint",
                                        ts_days_ago(60, 15, 30), duration=600, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-002", "phone", "inbound", "complaint",
                                        ts_days_ago(35, 10, 45), duration=420, rep_id="REP-002"))
    interactions.append(make_interaction("CUST-002", "phone", "inbound", "inquiry",
                                        ts_days_ago(15, 13, 0), duration=180, rep_id="REP-003"))

    # SCN-003: 2 interactions in last 90 days (positive)
    interactions.append(make_interaction("CUST-003", "phone", "inbound", "inquiry",
                                        ts_days_ago(50, 10, 0), duration=200, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-003", "phone", "inbound", "general",
                                        ts_days_ago(25, 14, 30), duration=150, rep_id="REP-002"))

    # SCN-004: 3 interactions in last 60 days (all negative)
    interactions.append(make_interaction("CUST-004", "phone", "inbound", "complaint",
                                        ts_days_ago(55, 9, 0), duration=540, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-004", "phone", "inbound", "complaint",
                                        ts_days_ago(40, 11, 15), duration=480, rep_id="REP-002"))
    interactions.append(make_interaction("CUST-004", "email", "inbound", "complaint",
                                        ts_days_ago(25, 16, 0), rep_id="REP-003"))

    # SCN-005: 0 in last 90 days; 1 interaction 8 months ago
    interactions.append(make_interaction("CUST-005", "phone", "inbound", "general",
                                        ts_days_ago(245, 10, 30), duration=180, rep_id="REP-001"))

    # SCN-006: 2 recent (one with transcript, one without)
    interactions.append(make_interaction("CUST-006", "phone", "inbound", "complaint",
                                        ts_days_ago(40, 14, 0), duration=420, rep_id="REP-002"))
    interactions.append(make_interaction("CUST-006", "phone", "inbound", "inquiry",
                                        ts_days_ago(20, 9, 45), duration=60, rep_id="REP-001"))
    # 1 older positive
    interactions.append(make_interaction("CUST-006", "phone", "inbound", "general",
                                        ts_days_ago(200, 11, 30), duration=200, rep_id="REP-003"))

    # SCN-007: 2 interactions in last 30 days
    interactions.append(make_interaction("CUST-007", "phone", "inbound", "complaint",
                                        ts_days_ago(25, 10, 0), duration=360, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-007", "phone", "inbound", "complaint",
                                        ts_days_ago(10, 15, 30), duration=300, rep_id="REP-002"))

    # SCN-008: 1 interaction 30 days ago
    interactions.append(make_interaction("CUST-008", "phone", "inbound", "inquiry",
                                        ts_days_ago(30, 11, 0), duration=240, rep_id="REP-003"))

    # SCN-009: 1 interaction 15 days ago (complaint)
    interactions.append(make_interaction("CUST-009", "phone", "inbound", "complaint",
                                        ts_days_ago(15, 9, 30), duration=480, rep_id="REP-001"))

    # SCN-010: 1 interaction 2 months ago (positive inquiry)
    interactions.append(make_interaction("CUST-010", "phone", "inbound", "inquiry",
                                        ts_days_ago(60, 13, 15), duration=180, rep_id="REP-002"))

    # SCN-011: 1 interaction for CUST-011, 40 days ago, positive
    interactions.append(make_interaction("CUST-011", "phone", "inbound", "general",
                                        ts_days_ago(40, 10, 45), duration=200, rep_id="REP-003"))

    # SCN-012: 2 recent positive + 1 older negative
    interactions.append(make_interaction("CUST-012", "phone", "inbound", "inquiry",
                                        ts_days_ago(45, 14, 0), duration=240, rep_id="REP-001"))
    interactions.append(make_interaction("CUST-012", "email", "inbound", "request",
                                        ts_days_ago(20, 10, 30), rep_id="REP-002"))
    interactions.append(make_interaction("CUST-012", "phone", "inbound", "complaint",
                                        ts_days_ago(125, 16, 0), duration=420, rep_id="REP-003"))

    scenario_count = len(interactions)

    # Background interactions (~170 more)
    bg_customers = [c for c in customers if c["customer_id"].startswith("CUST-0") and len(c["customer_id"]) > 8]
    channels = ["phone"] * 50 + ["email"] * 35 + ["chat"] * 15
    directions = ["inbound"] * 80 + ["outbound"] * 15 + ["internal_note"] * 5
    dispositions = ["inquiry"] * 35 + ["complaint"] * 15 + ["request"] * 25 + ["notification"] * 10 + ["general"] * 15

    for cust in bg_customers:
        n_ints = rng.randint(1, 4)
        for _ in range(n_ints):
            if len(interactions) >= 200:
                break
            channel = rng.choice(channels)
            direction = rng.choice(directions)
            disposition = rng.choice(dispositions)
            days_back = rng.randint(5, 350)
            dt = random_ts_business_hours(days_ago(days_back))
            duration = rng.randint(120, 900) if channel == "phone" else None
            rep_id = rng.choice(active_reps) if rng.random() > 0.05 else ""

            interactions.append({
                "interaction_id": f"INT-{int_counter[0]:06d}",
                "customer_id": cust["customer_id"],
                "channel": channel,
                "direction": direction,
                "disposition": disposition,
                "interaction_date": fmt_ts(dt),
                "duration_seconds": fmt_int(duration) if channel == "phone" and duration else "",
                "representative_id": rep_id,
            })
            int_counter[0] += 1
        if len(interactions) >= 200:
            break

    return interactions

# === 8. Transcripts ===
def generate_transcripts(interactions):
    transcripts = []
    trx_counter = [1]
    rng = random.Random(SEED + 7000)

    def make_transcript(interaction_id, content_type, text, consent=True):
        words = len(text.split())
        t = {
            "transcript_id": f"TRX-{trx_counter[0]:06d}",
            "interaction_id": interaction_id,
            "content_type": content_type,
            "raw_text": text,
            "word_count": str(words),
            "recording_consent_flag": fmt_bool(consent),
        }
        trx_counter[0] += 1
        return t

    # SCN-001: 4 transcripts (2 negative recent, 2 positive older)
    transcripts.append(make_transcript("INT-000001", "call_transcript", NEGATIVE_TRANSCRIPTS[0]))
    transcripts.append(make_transcript("INT-000002", "email_body", NEGATIVE_TRANSCRIPTS[1]))
    transcripts.append(make_transcript("INT-000003", "call_transcript", POSITIVE_TRANSCRIPTS[0]))
    transcripts.append(make_transcript("INT-000004", "call_transcript", POSITIVE_TRANSCRIPTS[1]))

    # SCN-002: 2 negative + 1 neutral
    transcripts.append(make_transcript("INT-000005", "call_transcript", NEGATIVE_TRANSCRIPTS[2]))
    transcripts.append(make_transcript("INT-000006", "call_transcript", NEGATIVE_TRANSCRIPTS[3]))
    transcripts.append(make_transcript("INT-000007", "call_transcript", NEUTRAL_TRANSCRIPTS[0]))

    # SCN-003: 2 positive
    transcripts.append(make_transcript("INT-000008", "call_transcript", POSITIVE_TRANSCRIPTS[2]))
    transcripts.append(make_transcript("INT-000009", "call_transcript", POSITIVE_TRANSCRIPTS[3]))

    # SCN-004: 3 negative
    transcripts.append(make_transcript("INT-000010", "call_transcript", NEGATIVE_TRANSCRIPTS[4]))
    transcripts.append(make_transcript("INT-000011", "call_transcript", NEGATIVE_TRANSCRIPTS[0]))
    transcripts.append(make_transcript("INT-000012", "email_body", NEGATIVE_TRANSCRIPTS[1]))

    # SCN-005: 1 positive on old interaction
    transcripts.append(make_transcript("INT-000013", "call_transcript", POSITIVE_TRANSCRIPTS[4]))

    # SCN-006: transcript for Interaction A (INT-000014), NO transcript for Interaction B (INT-000015)
    transcripts.append(make_transcript("INT-000014", "call_transcript", NEGATIVE_TRANSCRIPTS[2]))
    # Older positive interaction INT-000016
    transcripts.append(make_transcript("INT-000016", "call_transcript", POSITIVE_TRANSCRIPTS[0]))

    # SCN-007: Transcript 1 consent=FALSE, Transcript 2 consent=TRUE
    transcripts.append(make_transcript("INT-000017", "call_transcript", NEGATIVE_TRANSCRIPTS[3], consent=False))
    transcripts.append(make_transcript("INT-000018", "call_transcript", NEGATIVE_TRANSCRIPTS[4], consent=True))

    # SCN-008: 1 neutral
    transcripts.append(make_transcript("INT-000019", "call_transcript", NEUTRAL_TRANSCRIPTS[1]))

    # SCN-009: 1 negative (complaint)
    transcripts.append(make_transcript("INT-000020", "call_transcript", NEGATIVE_TRANSCRIPTS[0]))

    # SCN-010: 1 positive
    transcripts.append(make_transcript("INT-000021", "call_transcript", POSITIVE_TRANSCRIPTS[2]))

    # SCN-011: 1 positive
    transcripts.append(make_transcript("INT-000022", "call_transcript", POSITIVE_TRANSCRIPTS[3]))

    # SCN-012: 2 recent positive + 1 older negative
    transcripts.append(make_transcript("INT-000023", "call_transcript", POSITIVE_TRANSCRIPTS[4]))
    transcripts.append(make_transcript("INT-000024", "email_body", POSITIVE_TRANSCRIPTS[0]))
    transcripts.append(make_transcript("INT-000025", "call_transcript", NEGATIVE_TRANSCRIPTS[2]))

    scenario_trx_count = len(transcripts)

    # Background transcripts (~25 more, ~25% of background interactions get transcripts)
    bg_interactions = [i for i in interactions if int(i["interaction_id"].split("-")[1]) > 25]
    rng.shuffle(bg_interactions)
    bg_target = 50 - scenario_trx_count

    for inter in bg_interactions[:bg_target]:
        channel = inter["channel"]
        if channel == "phone":
            ct = "call_transcript"
        elif channel == "email":
            ct = "email_body"
        else:
            ct = "agent_note"

        # Pick a template based on disposition
        if inter["disposition"] == "complaint":
            text = rng.choice(NEGATIVE_TRANSCRIPTS)
        elif inter["disposition"] in ("inquiry", "request", "general"):
            text = rng.choice(POSITIVE_TRANSCRIPTS + NEUTRAL_TRANSCRIPTS)
        else:
            text = rng.choice(NEUTRAL_TRANSCRIPTS)

        consent = rng.random() > 0.05
        transcripts.append(make_transcript(inter["interaction_id"], ct, text, consent))

    return transcripts

# === 9. Scenario Expectations ===
def generate_scenario_expectations():
    expectations = [
        # SCN-001
        {"scenario_id": "SCN-001", "customer_id": "CUST-001", "signal_name": "renewal_proximity",
         "expected_value": "high", "test_note": "Auto policy expires in 16 days (within 30-day window)"},
        {"scenario_id": "SCN-001", "customer_id": "CUST-001", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "2", "test_note": "Two negative interactions within 90-day window"},
        {"scenario_id": "SCN-001", "customer_id": "CUST-001", "signal_name": "sentiment_direction",
         "expected_value": "worsening", "test_note": "Current window worse than prior window"},
        {"scenario_id": "SCN-001", "customer_id": "CUST-001", "signal_name": "payment_behavior",
         "expected_value": "good", "test_note": "All payments on-time"},
        {"scenario_id": "SCN-001", "customer_id": "CUST-001", "signal_name": "multi_policy_flag",
         "expected_value": "true", "test_note": "2 active policies"},
        # SCN-002
        {"scenario_id": "SCN-002", "customer_id": "CUST-002", "signal_name": "renewal_proximity",
         "expected_value": "high", "test_note": "Auto expires in 22 days"},
        {"scenario_id": "SCN-002", "customer_id": "CUST-002", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "2", "test_note": "Two negative interactions in 90 days"},
        {"scenario_id": "SCN-002", "customer_id": "CUST-002", "signal_name": "payment_behavior",
         "expected_value": "minor_risk", "test_note": "1 historical late payment"},
        # SCN-003
        {"scenario_id": "SCN-003", "customer_id": "CUST-003", "signal_name": "renewal_proximity",
         "expected_value": "high", "test_note": "Auto expires in 12 days"},
        {"scenario_id": "SCN-003", "customer_id": "CUST-003", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "0", "test_note": "All positive interactions"},
        {"scenario_id": "SCN-003", "customer_id": "CUST-003", "signal_name": "multi_policy_flag",
         "expected_value": "true", "test_note": "2 active policies"},
        # SCN-004
        {"scenario_id": "SCN-004", "customer_id": "CUST-004", "signal_name": "renewal_proximity",
         "expected_value": "low", "test_note": "130 days out"},
        {"scenario_id": "SCN-004", "customer_id": "CUST-004", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "3", "test_note": "3 negative interactions in 60 days"},
        # SCN-005
        {"scenario_id": "SCN-005", "customer_id": "CUST-005", "signal_name": "renewal_proximity",
         "expected_value": "high", "test_note": "Home expires in 20 days"},
        {"scenario_id": "SCN-005", "customer_id": "CUST-005", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "0", "test_note": "No interactions in 90-day window"},
        {"scenario_id": "SCN-005", "customer_id": "CUST-005", "signal_name": "sentiment_direction",
         "expected_value": "not_computable", "test_note": "No current-window data"},
        # SCN-006
        {"scenario_id": "SCN-006", "customer_id": "CUST-006", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "1", "test_note": "Only Interaction A has enrichable transcript"},
        {"scenario_id": "SCN-006", "customer_id": "CUST-006", "signal_name": "interaction_without_transcript",
         "expected_value": "INT-000015", "test_note": "Interaction B has no transcript row"},
        # SCN-007
        {"scenario_id": "SCN-007", "customer_id": "CUST-007", "signal_name": "consent_blocked_transcript",
         "expected_value": "TRX-000016", "test_note": "Transcript 1 has consent=FALSE"},
        {"scenario_id": "SCN-007", "customer_id": "CUST-007", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "1", "test_note": "Only consented transcript contributes"},
        # SCN-008
        {"scenario_id": "SCN-008", "customer_id": "CUST-008", "signal_name": "payment_behavior",
         "expected_value": "poor", "test_note": "3 late + 1 grace period"},
        {"scenario_id": "SCN-008", "customer_id": "CUST-008", "signal_name": "renewal_proximity",
         "expected_value": "low", "test_note": "45 days out"},
        # SCN-009
        {"scenario_id": "SCN-009", "customer_id": "CUST-009", "signal_name": "open_complaints",
         "expected_value": "1", "test_note": "Unresolved complaint 15 days ago"},
        {"scenario_id": "SCN-009", "customer_id": "CUST-009", "signal_name": "renewal_proximity",
         "expected_value": "high", "test_note": "Home expires in 22 days"},
        # SCN-010
        {"scenario_id": "SCN-010", "customer_id": "CUST-010", "signal_name": "multi_policy_flag",
         "expected_value": "false", "test_note": "Single renters policy"},
        {"scenario_id": "SCN-010", "customer_id": "CUST-010", "signal_name": "renewal_proximity",
         "expected_value": "low", "test_note": "60 days out"},
        # SCN-011
        {"scenario_id": "SCN-011", "customer_id": "CUST-011", "signal_name": "multi_policy_flag",
         "expected_value": "true", "test_note": "3 policies for CUST-011"},
        {"scenario_id": "SCN-011", "customer_id": "CUST-011", "signal_name": "household_policy_count",
         "expected_value": "4", "test_note": "4 policies across household HH-011"},
        {"scenario_id": "SCN-011", "customer_id": "CUST-011", "signal_name": "renewal_proximity",
         "expected_value": "high", "test_note": "Auto expires in 28 days"},
        # SCN-012
        {"scenario_id": "SCN-012", "customer_id": "CUST-012", "signal_name": "renewal_proximity",
         "expected_value": "very_high", "test_note": "Auto expires in 12 days"},
        {"scenario_id": "SCN-012", "customer_id": "CUST-012", "signal_name": "negative_sentiment_count_90d",
         "expected_value": "0", "test_note": "Recent interactions are positive"},
        {"scenario_id": "SCN-012", "customer_id": "CUST-012", "signal_name": "payment_behavior",
         "expected_value": "poor", "test_note": "2 late payments in 6 months"},
        {"scenario_id": "SCN-012", "customer_id": "CUST-012", "signal_name": "sentiment_direction",
         "expected_value": "improving", "test_note": "Prior window negative, current positive"},
    ]
    return expectations

# === Main ===
def main():
    print(f"Generating synthetic data (seed={SEED}, date={TODAY})...")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Generate in dependency order
    reps = generate_service_representatives()
    customers = generate_customers()
    policies = generate_policies(customers)
    coverages = generate_coverages(policies)
    claims = generate_claims(policies, customers)
    payments = generate_payments(policies, customers)
    interactions = generate_interactions(customers, reps)
    transcripts = generate_transcripts(interactions)
    expectations = generate_scenario_expectations()

    # Write CSVs
    files_info = []

    rep_fields = ["representative_id", "name", "role", "active", "team"]
    path = write_csv("service_representatives.csv", reps, rep_fields)
    files_info.append(("service_representatives.csv", len(reps), path))

    cust_fields = ["customer_id", "household_id", "first_name", "last_name", "customer_since",
                   "status", "date_of_birth", "email", "phone", "address_line_1", "city", "state", "postal_code"]
    path = write_csv("customers.csv", customers, cust_fields)
    files_info.append(("customers.csv", len(customers), path))

    pol_fields = ["policy_id", "customer_id", "product_type", "status", "effective_date",
                  "expiration_date", "premium_amount", "payment_frequency", "bound_date"]
    path = write_csv("policies.csv", policies, pol_fields)
    files_info.append(("policies.csv", len(policies), path))

    cov_fields = ["coverage_id", "policy_id", "coverage_type", "limit_amount", "deductible_amount"]
    path = write_csv("coverages.csv", coverages, cov_fields)
    files_info.append(("coverages.csv", len(coverages), path))

    clm_fields = ["claim_id", "policy_id", "customer_id", "filed_date", "status",
                  "loss_date", "loss_type", "reserve_amount", "paid_amount", "closed_date"]
    path = write_csv("claims.csv", claims, clm_fields)
    files_info.append(("claims.csv", len(claims), path))

    pay_fields = ["payment_id", "customer_id", "policy_id", "due_date", "amount",
                  "status", "paid_date", "amount_paid"]
    path = write_csv("payments.csv", payments, pay_fields)
    files_info.append(("payments.csv", len(payments), path))

    int_fields = ["interaction_id", "customer_id", "channel", "direction", "disposition",
                  "interaction_date", "duration_seconds", "representative_id"]
    path = write_csv("interactions.csv", interactions, int_fields)
    files_info.append(("interactions.csv", len(interactions), path))

    trx_fields = ["transcript_id", "interaction_id", "content_type", "raw_text",
                  "word_count", "recording_consent_flag"]
    path = write_csv("transcripts.csv", transcripts, trx_fields)
    files_info.append(("transcripts.csv", len(transcripts), path))

    exp_fields = ["scenario_id", "customer_id", "signal_name", "expected_value", "test_note"]
    path = write_csv("scenario_expectations.csv", expectations, exp_fields)
    files_info.append(("scenario_expectations.csv", len(expectations), path))

    # Generate manifest
    manifest = {
        "seed": SEED,
        "generation_date": fmt_date(TODAY),
        "generator_version": GENERATOR_VERSION,
        "files": []
    }
    for filename, row_count, filepath in files_info:
        manifest["files"].append({
            "filename": filename,
            "row_count": row_count,
            "sha256": sha256_file(filepath),
        })

    manifest_path = OUTPUT_DIR / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(f"\nGeneration complete. Files written to: {OUTPUT_DIR}")
    print(f"\nRow counts:")
    for filename, row_count, _ in files_info:
        print(f"  {filename}: {row_count} rows")
    print(f"\n  manifest.json written")


if __name__ == "__main__":
    main()
