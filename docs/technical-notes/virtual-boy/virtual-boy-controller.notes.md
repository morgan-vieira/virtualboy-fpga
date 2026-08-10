# Notes: Virtual Boy Controller (wiki article source)

## Source

- File: `Virtual_Boy_Controller.wikitext`
- Type: MediaWiki markup (wikitext) source of a wiki article — reference/encyclopedia style, not a vendor specification
- Extent: 34 lines, roughly 200 words including markup; one level-2 section heading (`== References ==`)
- Version or date stated in document: not stated. The wikitext carries no revision id, timestamp, or version marker. The only embedded date is inside an archive URL, `20190319100353` [L31]
- Author or publisher stated in document: not stated. No signature, byline, or attribution template appears
- Title stated in document: none in the body; the article title is carried only by the filename, `Virtual_Boy_Controller.wikitext`

## Scope

The document describes the Virtual Boy controller's serial report format: it states the controller has an NES-compatible protocol, lists the 16 bits readable after strobing, and compares the report to the SNES controller's [L1, L8–28]. It names two homebrew games that have used the controller [L3–4] and ends with a four-item References section [L30–34]. It does not cover connector pinout, electrical levels, strobe or clock timing, polling rate, the Virtual Boy console itself, or the controller's mechanical design.

## Key concepts

- **Strobing** — the action that precedes reading; the document states that after strobing the controller, 16 bits can be read from the data line [L8]. The document does not define the strobe signal, its timing, or its pin.
- **Data line** — the single line from which the 16 bits are read [L8]. Not otherwise specified.
- **NES-compatible protocol** — the description the document gives of the Virtual Boy controller's protocol [L1].
- **Left D-pad / Right D-pad** — the two directional pads the bit list distinguishes [L14–20].

## Content

### Lead (L1–4)

- The Virtual Boy controller has an NES-compatible protocol, and has been used in homebrew games [L1].
- Two homebrew titles are listed, both in italic markup (`''...''`) [L3–4]:
  - *Spook-O'-Tron* [L3]
  - *Candelabra - Estoscerro* [L4]

### Category tag (L6)

- The wikitext places `[[Category:Controllers]]` at line 6, in the middle of the article body, before the report-format text that follows at line 8 [L6]. Category tags conventionally sit at the end of a wikitext page; this one does not.

### Report format (L8–26)

- After strobing the controller, the following 16 bits can be read from the data line [L8].
- The bit list is written as two indented preformatted blocks (leading-space MediaWiki `pre` formatting) separated by a blank line: bits 0–7 [L10–17] and bits 8–15 [L19–26].

### Comparison to other controllers (L28)

- The document states the report is "very analogous to the [[SNES controller]]", which reports its 4 face buttons where the Virtual Boy reports its right d-pad [L28].
- The document states the last 4 bits (B, A, 1, battery) have no correspondence in the SNES controller report [L28].
- The document states: "Use this 1 to distinguish the Virtual Boy controller from that controller or a [[mouse]]." [L28]. The "1" referred to is the always-1 value at bit 14 [L25, L28].

### References section (L30–34)

- Section heading is `== References ==` [L30].
- The section is a plain bulleted list of four external links. There are no `<ref>` footnotes, no citation templates, and no inline citation markers anywhere in the article [L30–34].
- Reference 1: "VB Sacred Tech Scroll: Virtual Boy Specifications", linked protocol-relative to `//web.archive.org/web/20190319100353/perfectkiosk.net/stsvb.html#hardwaregamepad` [L31].
- Reference 2: "PlanetVB: Documents", linked to `https://www.planetvb.com/modules/tech/?sec=docs` [L32].
- Reference 3: "Sly Dog Studios: Candelabra - Estoscerro demo available", linked to `https://slydogstudios.org/` [L33].
- Reference 4: "Forum post: Spook-o'-tron - Virtual Boy Controller Fun", linked protocol-relative to `//forums.nesdev.org/viewtopic.php?f=22&t=15677` [L34].

## Specifications and procedures

### The 16-bit report, verbatim

Introduced by "After strobing the controller, the following 16 bits can be read from the data line:" [L8].

| Bit | Meaning as printed               |
| --- | -------------------------------- |
| 0   | Right D-pad Down                 |
| 1   | Right D-pad Left                 |
| 2   | Select                           |
| 3   | Start                            |
| 4   | Left D-pad Up                    |
| 5   | Left D-pad Down                  |
| 6   | Left D-pad Left                  |
| 7   | Left D-pad Right                 |
| 8   | Right D-pad Right                |
| 9   | Right D-pad Up                   |
| 10  | L (rear left trigger)            |
| 11  | R (rear right trigger)           |
| 12  | B                                |
| 13  | A                                |
| 14  | Always 1                         |
| 15  | Battery voltage; 1 = low voltage |

[L10–26]

### Identification procedure as stated

- Bit 14 is always 1 [L25].
- The document instructs the reader to use that 1 to distinguish the Virtual Boy controller from the SNES controller or from a mouse [L28].

## Constraints and requirements

- Bit 14 is stated as invariant: "Always 1" [L25].
- Bit 15 is a battery voltage indicator with the polarity stated as `1 = low voltage` [L26].
- Reading the 16 bits is stated to require strobing the controller first [L8].
- The correspondence with the SNES controller is stated to hold only for the first 12 bits; the last 4 bits (B, A, 1, battery) are stated to have no SNES counterpart [L28].

## Editorial apparatus present in the wikitext

- Internal wikilinks: `[[SNES controller]]` and `[[mouse]]` [L28].
- Category link: `[[Category:Controllers]]` [L6].
- Italic markup on the two game titles: `''Spook-O'-Tron''`, `''Candelabra - Estoscerro''` [L3–4].
- Protocol-relative external links (`//host/path`) used for references 1 and 4; full `https://` URLs used for references 2 and 3 [L31–34].
- Section heading markup: `== References ==` [L30].
- Preformatted blocks created by leading spaces rather than `<pre>` tags [L10–26].
- No infobox: the wikitext contains no template transclusion of any kind (no `{{...}}` syntax anywhere), therefore no infobox fields exist to record [L1–34].
- No `<ref>` tags, no `{{reflist}}`, no `<references />` [L1–34].

## Stated gaps and ambiguities

- The article title appears nowhere in the wikitext body; only the filename carries it.
- The document does not define the strobe signal, clock signal, pin assignments, connector type, voltage levels, or timing — it names only "strobing" and "the data line" [L8].
- The document does not state the shift order of the 16 bits explicitly; only the numbering 0 through 15 is given [L10–26].
- The document does not state whether a set bit means pressed or released for the button bits; only bit 15's polarity is given (`1 = low voltage`) [L26].
- The two homebrew titles listed in the lead [L3–4] are not connected in the text to the report format that follows; the document does not say what role the games play beyond having used the controller [L1].
- `[[Category:Controllers]]` sits mid-article at L6 rather than at the end, so the wikitext's structure is irregular; the document gives no explanation [L6].
- The claim of an "NES-compatible protocol" [L1] is not reconciled with the 16-bit report length or with the SNES comparison [L28]; the document does not state how a 16-bit report relates to the NES protocol.
- The References section lists four sources but nothing in the body cites any of them, so no individual claim in the article is attributed to a specific source [L30–34].
- Reference 1 is given only as a Wayback Machine capture of `perfectkiosk.net/stsvb.html`; the document does not state the original page's publication date or author [L31].
