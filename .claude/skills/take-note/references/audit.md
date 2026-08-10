# The containment audit

Run this after the notes are drafted, as a distinct pass over the finished text. Auditing while writing doesn't work: the same context that produced a leak makes the leak look natural on the way past.

## Contents

- [The containment audit](#the-containment-audit)
  - [Contents](#contents)
  - [The two tests](#the-two-tests)
  - [Leak taxonomy](#leak-taxonomy)
  - [Worked examples](#worked-examples)
  - [What is not a leak](#what-is-not-a-leak)
  - [Audit procedure](#audit-procedure)
  - [Reporting](#reporting)

## The two tests

**Trace test — outbound.** Every factual sentence must trace to a specific location in the document. Anchors make this checkable: walk the notes, and for each anchored claim confirm the source actually says that at that location. Unanchored factual sentences are the ones to scrutinise — they're either structural framing (fine), marked inference (fine), or a claim that came from somewhere other than the document (not fine).

**Isolation test — inbound.** For each sentence: would this exist, in these words, at this length, if the document had arrived with no task attached? This catches what the trace test can't — a sentence can be perfectly faithful to the document and still be there only because of the task, and its presence, prominence, or phrasing leaks the task to a later reader.

Both tests apply to *what was left out* as well. A section compressed to nothing because it wasn't useful today fails the isolation test just as surely as an added recommendation.

## Leak taxonomy

Ordered roughly by how often it happens.

1. **Relevance commentary** — "This is the section that matters for the migration", "Note this for later", "Important given the current setup". Any sentence whose function is to rank the document's content against an external purpose.
2. **Recommendations and next actions** — "Should use the async client here", "We'll need to update the config". Notes record what the document says; they don't issue instructions.
3. **First and second person about the current work** — "our", "we", "your codebase", "the team". Not to be confused with the document's own first person, which is fine when attributed.
4. **External proper nouns** — repos, branches, tickets, services, vendors, colleagues, filenames, tools that appear nowhere in the source document. The most obvious leak and the easiest to grep for.
5. **Emphasis distortion** — the task-relevant section gets twelve detailed bullets, three comparably sized sections get one each. Nothing written is false; the shape still transmits the task.
6. **Task-driven omission** — an entire section skipped as "not relevant". Invisible in the finished file, which makes it the most dangerous kind, and the reason coverage is checked against the source's structure rather than against the notes alone.
7. **Imported knowledge** — filling a gap in the document from your own training or from another source in the conversation, unmarked. Later readers will attribute it to the document.
8. **Premature resolution** — the document is ambiguous or two documents conflict, and the notes pick a winner. The choice came from task knowledge.
9. **Answering the question** — the user asked something, and the answer is embedded in the notes rather than given in the reply.

## Worked examples

**Relevance commentary**

- Contaminated: `Section 4 covers connection pooling — this is the part relevant to the timeout issue. [§4]`
- Clean: `Section 4 specifies connection pooling behaviour, including pool sizing and idle eviction. [§4]`

**Recommendation**

- Contaminated: `Use the batch endpoint instead, since it handles the volumes involved here. [p.11]`
- Clean: `The document recommends the batch endpoint for request volumes above 1,000/minute. [p.11]`

**External proper noun**

- Contaminated: `Auth flow is OAuth2 client credentials, same as what payments-api uses. [§2.1]`
- Clean: `Auth flow is OAuth2 client credentials grant. [§2.1]`

**Imported knowledge**

- Contaminated: `Default retry count is 3. The exponential backoff is capped at 30 seconds. [§5]`, where the cap is something you know from elsewhere.
- Clean: `Default retry count is 3 [§5]. The document does not state a backoff cap.`

**Premature resolution**

- Contaminated: `Timeout is 60s (the 30s figure in §2 appears to be outdated). [§7]`
- Clean: `§2 states a 30s timeout; §7 states 60s. The document does not reconcile these. [§2, §7]`

**Attribution of the document's voice**

- Contaminated: `We recommend enabling compression for payloads over 1MB. [p.6]`
- Clean: `The document recommends enabling compression for payloads over 1MB. [p.6]`

## What is not a leak

Over-scrubbing produces notes that are useless in a different way. These are all fine:

- **The document's own project, product, company, and people.** In scope, in full detail, however specific.
- **Technical vocabulary that happens to match the current task.** If the document is about caching and the task is about caching, the notes are about caching. Shared subject matter isn't contamination — the test is whether *task* facts entered, not whether topics overlap.
- **Structural and navigational sentences** — "Section 3 is a worked example", "The appendix lists error codes". These describe the document.
- **Explicitly marked inference** — `Inferred, not stated: the two endpoints appear to share a rate limit bucket.` Marked, it's honest and useful. Unmarked, it's leak type 7.
- **Recorded gaps** — noting the document never defines a term is a fact about the document.

## Audit procedure

1. **Grep the obvious.** Search the notes for `we `, `our `, `your `, `us `, and for proper nouns that don't appear in the source. Fast, catches types 3 and 4.
2. **Isolation-test every sentence** in `Scope`, `Content`, and `Constraints`. These sections carry the most prose and take the most contamination.
3. **Trace-test the anchors.** Spot-check claims against the source, and check every unanchored factual sentence.
4. **Check coverage against the source structure**, not against the notes. Walk the document's table of contents or section list and confirm each part is represented at roughly proportional depth. This is the only reliable way to catch type 6.
5. **Check emphasis balance.** Compare bullet counts per section against section sizes in the source. A large ratio gap is type 5.
6. **Fix and re-run.** Fixing one leak often reveals another, because the sentence propping it up loses its justification. Re-run steps 2–5 after any substantive edit.

## Reporting

Report the audit in the chat reply, briefly and concretely — it's the user's evidence that containment held, and vague reassurance is worth nothing.

> Audit: 3 flags. Two relevance-commentary sentences in Content removed; one recommendation in §4 rewritten as an attributed statement of what the document recommends. Coverage checked against the source's 9 sections, all represented.

If nothing was flagged, say so plainly. If something couldn't be fixed without losing real content — a genuine judgement call — surface it and let the user decide rather than settling it silently.