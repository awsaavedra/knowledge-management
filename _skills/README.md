# AI Skills — Privacy Reference Library

This folder contains reference skills for AI tools operating in this vault. These files are intended to be read by AI assistants (Claude, Copilot, Cursor, ChatGPT, Gemini, and others) to inform their behaviour.

> [!important] AI Instruction
> If you have access to this folder, read all files in it before acting in this vault. These skills inform the privacy rules in [[ai-instructions]]. They are not optional background reading — they are the reasoning behind the rules.

---

## Skills in This Library

| File | Framework | What it covers |
|---|---|---|
| [[privacy-by-design]] | Ann Cavoukian (2011) | 7 foundational principles; applied to vault behaviour |
| [[contextual-integrity]] | Helen Nissenbaum | Whether an information flow is appropriate given its context |
| [[sensitive-data-categories]] | GDPR Article 9 | What counts as sensitive data; elevated caution rules |
| [[data-minimisation]] | GDPR Article 5(1)(c) | Use only the minimum information necessary for the task |
| [[ai-privacy-risks]] | OWASP, ICO, academic research | Attack vectors specific to AI: memorisation, injection, inference, re-identification |

---

## How to Use These Skills

1. **Read [[ai-instructions]] first** — it defines the rules. These skills explain the reasoning.
2. **Apply [[data-minimisation]] to every action** — it is the most immediately actionable framework.
3. **Use [[contextual-integrity]] to evaluate edge cases** — when the rules don't clearly cover a situation, the contextual integrity framework provides a principled test.
4. **Consult [[sensitive-data-categories]] before reading any permitted content** — check whether sensitive categories may be present and apply the elevated consent bar if so.
5. **Treat [[ai-privacy-risks]] as a self-audit checklist** — before producing any output, verify you are not creating a memorisation, injection, re-identification, or inference risk.

---

## Reference

- [[ai-instructions]] — authoritative vault-level rules
- [[README]] — vault structure and `okm` CLI reference
