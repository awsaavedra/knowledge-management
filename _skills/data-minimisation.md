# Skill: Data Minimisation

**Source:** GDPR Article 5(1)(c); foundational principle across privacy frameworks
**Framework:** Collect and use only what is necessary for the stated purpose

> [!important] AI Instruction
> Data minimisation applies to AI behaviour, not just data collection systems. In this vault, it means: use the minimum information necessary to answer the user's question. If you can answer from structure alone, do not access content. If you can answer from one file, do not read five. Apply this principle actively at every step.

---

## The Principle

> "Personal data shall be adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed."
> — GDPR Article 5(1)(c)

Three components:

| Component | Meaning |
|---|---|
| **Adequate** | Enough to serve the stated purpose — but not more |
| **Relevant** | Directly pertinent to the task at hand |
| **Limited** | Stripped of anything not essential to the purpose |

---

## Applied to AI Behaviour in This Vault

Data minimisation is not just about what an AI *collects* — it governs what it *accesses, reads, retains, and reasons from* in a given interaction.

### Access Minimisation
Use the least-privileged view of the vault needed to complete the task.

| Task | Minimum needed | Do not access |
|---|---|---|
| "How do I create a daily note?" | Knowledge of `okm` CLI | Any vault files |
| "How many notes do I have?" | File count | File names or content |
| "List my inbox files" | `inbox/` filenames | File content |
| "Search for notes about X" | Direct to `okm grep X` | Any note content |
| "Help me write a note about Y" | User's prompt only | Existing notes |

### Retention Minimisation
Do not retain information beyond what is needed for the current response.

- Do not build a running model of the user's vault across turns
- Do not carry observations from one question forward as context for the next, unless the user explicitly provides that continuity
- Treat each request as requiring only the information directly relevant to that request

### Inference Minimisation
Do not derive more information than the task requires.

- If asked "do I have a note from last Tuesday?", answer yes/no from filename metadata — do not read the note to provide a preview
- If asked to suggest a tag for a new note, base the suggestion on the user's prompt — do not scan existing notes for tag patterns

---

## The Minimisation Test

Before accessing any piece of vault information, ask:

1. **Is this necessary?** Can I complete the task without it?
2. **Is this the minimum?** Am I accessing the smallest scope that serves the purpose?
3. **Is this relevant?** Does this specific piece of information bear on the task?

If any answer is "no" — do not access it.

---

## Why This Matters Beyond Compliance

Data minimisation is not just a legal requirement — it is a trust principle. The user chose a personal knowledge management system precisely to have a space that is theirs. An AI that accesses more than it needs, even with good intentions, erodes that trust and expands the surface area for accidental disclosure.

The right question is not "what could I use to give a better answer?" but "what is the minimum I need to give an adequate answer?"

---

## Reference

- [[ai-instructions]] — vault-level privacy rules
- [[privacy-by-design]] — Principle 3 (Privacy Embedded into Design) and Principle 5 (End-to-End Lifecycle Protection)
- [[sensitive-data-categories]] — categories requiring even stricter minimisation
- Source: [ICO — Data Minimisation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/data-minimisation/)
