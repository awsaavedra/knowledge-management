# Skill: Sensitive Data Categories

**Source:** GDPR Article 9 and complementary guidance from national data protection authorities
**Framework:** Special Category Personal Data

> [!important] AI Instruction
> This file defines what counts as sensitive personal data. When operating in this vault, apply heightened caution if any of these categories could be present in note content or inferable from filenames. The presence of sensitive data categories raises the privacy bar — do not engage with such content without explicit, specific user permission.

---

## What Counts as Sensitive Data

The following categories receive the highest level of privacy protection because their misuse creates significant risk to fundamental rights and personal safety.

### 1. Health and Medical Data
- Medical diagnoses, conditions, or symptoms
- Mental health information
- Medication, treatment records, or clinical notes
- Information derived from physical or mental examination
- Disability status

**In this vault:** A note in `inbox/` with a health-related filename, or a daily note mentioning a medical appointment, may contain health data. Do not read, summarise, or reference.

---

### 2. Mental Health and Psychological State
- Emotional distress, anxiety, depression, or other psychological conditions
- Therapy notes or reflections
- Mood tracking or journaling about internal states

**In this vault:** Daily notes frequently contain personal emotional content. Treat all daily note bodies as potentially containing mental health data.

---

### 3. Financial Data
- Account details, balances, debts, or financial struggles
- Income, salary, or net worth information
- Spending patterns or financial decisions

---

### 4. Biometric and Identity Data
- Physical identifiers (fingerprints, facial features described in notes)
- Location data that could establish home address or routine
- Unique identifiers tied to physical presence

---

### 5. Racial or Ethnic Origin
- Any information revealing racial background, nationality, or ethnic identity

---

### 6. Political and Religious Beliefs
- Political opinions, affiliations, or voting behaviour
- Religious practice, affiliation, or philosophical beliefs
- Trade union membership or labour organizing activity

---

### 7. Sexual Orientation and Intimate Relationships
- Sexual orientation or identity
- Relationship status, romantic or intimate details
- Sexual practices or preferences

---

### 8. Legal and Criminal Data
- Past or current legal proceedings
- Criminal history or accusations
- Legal disputes or pending matters

---

## How to Apply This in Practice

**Step 1 — Category check before acting:**
Before engaging with any note content (even when explicitly permitted), identify whether sensitive categories could be present. If yes, confirm the user still wants you to proceed.

**Step 2 — Filename inference prohibition:**
Filenames like `therapy.md`, `diagnosis.md`, `finances-2026.md`, or `relationship-thoughts.md` signal potential sensitive data. Do not comment on, infer from, or acknowledge these filenames beyond their existence unless the user raises them.

**Step 3 — Elevated caution in daily notes:**
Daily notes (`daily/YYYY-MM-DD.md`) routinely capture unfiltered personal experience and are the most likely location for sensitive category data. Treat their content as sensitive by default.

**Step 4 — No inference chaining:**
Do not combine structural observations (frequency of notes, folder activity, filename patterns) to infer sensitive category information about the user. Example: noting that a user has many recent notes in `inbox/` with emotional-seeming slugs is not a basis for inferring mental health status.

---

## Sensitive Data = Higher Consent Bar

For ordinary note content: user explicit permission is required to read.

For content that may contain sensitive category data: explicit, specific permission for that category is required. "You can read my notes" is not the same as "you can read my health notes."

> [!warning]
> If you encounter sensitive category data unexpectedly (e.g., through automatic context injection), stop, inform the user that sensitive data has appeared in context, and ask how they want to proceed. Do not process it silently.

---

## Reference

- [[ai-instructions]] — vault-level privacy rules
- [[contextual-integrity]] — framework for evaluating appropriate information flows
- Source: [GDPR Article 9 — GDPR Info](https://gdpr-info.eu/art-9-gdpr/), [ICO Special Category Data](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/)
