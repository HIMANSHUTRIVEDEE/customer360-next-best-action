# Synthetic Data Validation Results

**Timestamp:** 2026-08-26T22:08:37.602659

| # | Check Name | Status | Detail |
|---|-----------|--------|--------|
| 1 | check_files_exist | PASS |  |
| 2 | check_manifest_matches | PASS |  |
| 3 | check_pk_customers | PASS |  |
| 4 | check_pk_policies | PASS |  |
| 5 | check_pk_coverages | PASS |  |
| 6 | check_pk_claims | PASS |  |
| 7 | check_pk_payments | PASS |  |
| 8 | check_pk_interactions | PASS |  |
| 9 | check_pk_transcripts | PASS |  |
| 10 | check_pk_service_reps | PASS |  |
| 11 | check_fk_policies_customers | PASS |  |
| 12 | check_fk_coverages_policies | PASS |  |
| 13 | check_fk_claims_policies | PASS |  |
| 14 | check_fk_claims_customers | PASS |  |
| 15 | check_fk_claims_ownership | PASS |  |
| 16 | check_fk_payments_customers | PASS |  |
| 17 | check_fk_payments_policies | PASS |  |
| 18 | check_fk_interactions_customers | PASS |  |
| 19 | check_fk_interactions_reps | PASS |  |
| 20 | check_fk_transcripts_interactions | PASS |  |
| 21 | check_transcript_one_per_interaction | PASS |  |
| 22 | check_active_policies_have_coverage | PASS |  |
| 23 | check_policy_dates | PASS |  |
| 24 | check_payment_amounts_positive | PASS |  |
| 25 | check_enum_customer_status | PASS |  |
| 26 | check_enum_product_type | PASS |  |
| 27 | check_enum_policy_status | PASS |  |
| 28 | check_enum_payment_frequency | PASS |  |
| 29 | check_enum_payment_status | PASS |  |
| 30 | check_enum_claim_status | PASS |  |
| 31 | check_enum_channel | PASS |  |
| 32 | check_enum_direction | PASS |  |
| 33 | check_enum_disposition | PASS |  |
| 34 | check_enum_content_type | PASS |  |
| 35 | check_enum_rep_role | PASS |  |
| 36 | check_consent_flag_populated | PASS |  |
| 37 | check_word_count_matches | PASS |  |
| 38 | check_all_scenarios_represented | PASS |  |
| 39 | check_maria_chen_golden_demo | PASS |  |
| 40 | check_no_nba_or_enrichment_fields | PASS |  |
| 41 | check_no_credential_patterns | PASS |  |
| 42 | check_no_real_pii_patterns | PASS |  |
| 43 | check_reproducibility | PASS |  |

**43/43 checks passed.**
