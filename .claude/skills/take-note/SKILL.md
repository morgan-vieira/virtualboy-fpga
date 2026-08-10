---
name: document-notes
description: Turn one or more source documents (PDF, Word, Markdown, slides, spec sheets, papers, RFCs, transcripts, API docs) into self-contained technical notes written for another AI agent to read later. Every note is audited so it describes only the document itself and carries no trace of the task, repo, or project it was produced for. Use this whenever the user asks to take notes on, summarise, digest, extract, condense, or "make a reference from" a document — and also when they ask for notes another agent, a subagent, or a future session will consume, even if they don't say the word "notes".
---

# Document Notes

Produce notes that a different agent, with no access to this conversation, could pick up months from now and use as a faithful stand-in for the source document.

Two properties make notes good for that reader, and they pull in opposite directions unless handled deliberately:

- **Density** — the notes must carry the document's technical content (values, constraints, procedures, definitions) precisely enough that the reader rarely needs the original.
- **Containment** — the notes must carry _nothing else_. No task context, no project details, no relevance judgements, no inferences dressed up as facts.

Containment is the property that decays first and the one this skill audits explicitly. Notes contaminated with the context they were written in look fine on the day they're written and become actively misleading the moment they're reused somewhere else, because a later reader can't tell which parts came from the document and which came from a task they know nothing about.

## The containment rule

**Notes describe the document. They do not describe the work the document is being read for.**

The test to apply to every sentence:

> If I had been handed this document alone, with no task, no repo, no conversation, and no instructions beyond "take notes" — would I have written this sentence, in these words, at this length?

If no, the sentence is contaminated. Cut it or rewrite it.

An important distinction, because it trips people up: if the _document_ is about a project, the notes obviously talk about that project — that content is in scope. What must stay out is the project **you** are working on. `document-notes` never conflates the two.

- Document is a spec for Kafka → notes discuss Kafka in full detail. Correct.
- Document is a spec for Kafka, and you're reading it to fix a consumer lag bug → notes must not mention consumer lag bugs, your service, or which sections matter for the fix. Contaminated.

### When the user wants task-relevant analysis too

They often do, and that's a reasonable thing to want. Deliver it **in the chat reply, not in the notes file**. The notes file stays clean; the conversation carries the "here's what this means for what you're doing" part. Say so plainly when handing over, so the user understands the split rather than thinking you ignored half their request.

## Workflow

### 1. Read the whole document first

Read completely before writing anything. Notes written while reading over-weight the early sections and drift toward whatever the current task made salient.

For long documents, do an inventory pass first: section structure, page/slide count, what kind of document this is (spec, tutorial, reference, paper, transcript, marketing). The document _type_ drives what the notes should preserve — a spec's value is in its exact constraints, a tutorial's is in its ordered procedure, a paper's is in its method and stated results.

If several documents were supplied, read each one fully and take its notes independently before looking at relationships between them (see [Multiple documents](#multiple-documents)).

### 2. Inventory the load-bearing facts

Before drafting, list the things that would be wrong to paraphrase loosely: exact identifiers, flags, function signatures, error codes, numeric values with units, version numbers, defaults, thresholds, required-vs-optional distinctions. These get carried across verbatim. Everything else gets compressed.

### 3. Write the notes

Follow the [format](#note-format) and the [writing rules](#writing-rules-for-agent-readers).

Coverage should be roughly proportional to the source. A section that's 30% of the document should not be 3% of the notes because it wasn't interesting for the current task — that's containment failure expressing itself as omission, which is harder to spot than contamination by addition.

### 4. Run the containment audit

A separate pass, after the notes are drafted, not a mindset held while drafting. Read `references/audit.md` and work the checklist against the finished text. This is the step that makes the skill worth invoking; don't fold it into step 3 and call it done.

### 5. Save and report

Write to `notes/<document-slug>.notes.md` unless the user specified a location. In the chat reply, state where the file is, give a two-line description of the document, report the audit outcome (what was flagged and what was done about it), and _then_ add any task-relevant analysis the user asked for.

## Note format

Use this structure. A consistent, greppable skeleton matters more than an elegant one — agent readers navigate by heading and often load only one section.

```markdown
# Notes: <document title as the document states it>

## Source

- File: <filename>
- Type: <spec | reference | tutorial | paper | transcript | slides | other>
- Extent: <pages / slides / word count>
- Version or date stated in document: <value, or "not stated">
- Author or publisher stated in document: <value, or "not stated">

## Scope

Two or three sentences: what the document covers, and what it explicitly
says it does not cover. Non-scope is worth recording — it stops a later
reader searching the notes for something the source never had.

## Key concepts

- **<Term>** — definition as this document uses it. [anchor]

## Content

Headings mirroring the document's own section structure.
One claim per bullet. Every bullet ends with a location anchor.

## Specifications and procedures

Exact values, parameters, ordered steps, signatures, schemas.
Verbatim for anything load-bearing.

## Constraints and requirements

Requirements, prohibitions, defaults, limits, ranges, version dependencies.
Preserve the document's own modal strength — a "should" must not become
a "must" in the notes.

## Stated gaps and ambiguities

Points the document leaves undefined, contradicts itself on, or defers
elsewhere. Record the ambiguity; do not resolve it.
```

Drop a section if the document genuinely has nothing for it — an empty heading is noise. Keep `Source` and `Scope` always.

### Location anchors

Every factual bullet ends with a pointer back to the source: `[p.14]`, `[§3.2]`, `[slide 7]`, `[L120–134]`, `[table 2]`. Anchors are what let a later reader verify a claim instead of trusting it, and they make the trace test in the audit mechanical rather than a judgement call.

## Writing rules for agent readers

Written-for-agents does not mean terse or stripped of prose. It means every sentence survives being read in isolation, out of order, with no surrounding context.

- **Resolve every reference.** No "this", "the above", "as mentioned", "it" pointing at a previous bullet. Name the thing. A reader may have loaded only this line.
- **One claim per bullet.** Compound bullets can't be cited, contradicted, or updated individually.
- **Front-load the subject.** `Retry backoff defaults to 500ms` beats `By default, and unless overridden, the backoff is 500ms`.
- **Use the document's own names.** Don't normalise its terminology to something more standard. If the document calls it a "shard leader" and the industry says "primary", record `shard leader (called "primary" elsewhere in the document) [§2]` once, then use the document's term throughout.
- **Never round or tidy values.** `4096` does not become "about 4k". `v2.11.3` does not become "v2".
- **Separate stated from inferred.** Default to recording only what the document states. Where an inference is genuinely useful, mark it: `Inferred, not stated: …`. An unmarked inference is indistinguishable from a fact to the next reader, which is how notes quietly become wrong.
- **Attribute the document's voice.** The document's "we recommend" becomes `The document recommends…`, so a later reader never mistakes the source's opinion for the note-taker's.
- **Preserve hedges as the document set them.** If the source says a result is preliminary, the note says preliminary.

## Multiple documents

One notes file per document, each written independently and audited independently. A merged mega-note loses the ability to say which document a fact came from, and that provenance is usually the most valuable thing in a multi-document set.

Then add `notes/INDEX.md`:

- A table listing each document: filename, type, extent, one-line scope.
- **Relationships evidenced in the documents themselves** — document B cites document A; document C supersedes B and says so; two documents state different values for the same parameter. Each relationship gets anchors in both documents.

Record contradictions; don't resolve them. Resolving requires knowing which source is authoritative, which is task knowledge, and importing it fails containment. `Doc A states timeout 30s [§4.1]; Doc B states 60s [p.9]. Not reconciled in either document.` is the correct note.

## Edge cases

- **The document is largely irrelevant to the task.** Take full notes anyway. Judging relevance is exactly the task knowledge that must not enter the file. Mention the mismatch in the chat reply instead.
- **The document is thin or low-quality.** Note what it contains and note the gaps in `Stated gaps and ambiguities`. Don't fill holes from your own knowledge — for a later reader, that's indistinguishable from the document having said it.
- **The user asks for notes "focused on X".** Honour it as ordering and emphasis within complete coverage, not as filtering. Put X's section first if it helps; still cover the rest. If they explicitly want a filtered extract, say plainly that the result is an extract rather than notes on the document, and label the file so a later reader isn't misled about what's missing.
- **The document contains sensitive material** (credentials, keys, personal data). Record that a credential exists and where, never its value: `Configuration block includes an API key value [p.3, redacted in notes]`.
- **The source is very long.** Keep proportional coverage but raise the compression ratio uniformly. Uneven compression across a long document is contamination hiding as summarisation.
