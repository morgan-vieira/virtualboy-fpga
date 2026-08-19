# Notes: Virtual Boy Controller (wiki article source)

## Source

- File: `Virtual_Boy_Controller.wikitext`
- Type: MediaWiki markup (wikitext) source of a wiki article. The style is encyclopedic, not a vendor specification
- Extent: 34 lines, roughly 200 words including markup. One level-2 section heading, `== References ==`
- Version or date stated in document: not stated. The wikitext carries no revision id, timestamp, or version marker. The only embedded date sits inside an archive URL, `20190319100353` [L31]
- Author or publisher stated in document: not stated. No signature, byline, or attribution template appears
- Title stated in document: none in the body. Only the filename `Virtual_Boy_Controller.wikitext` carries the article title

## Scope

The document describes the Virtual Boy controller's serial report format. It states that the controller has an NES-compatible protocol, lists the 16 bits readable after strobing, and compares the report to the SNES controller's [L1, L8–28]. The document also names two homebrew games that have used the controller [L3–4] and ends with a four-item References section [L30–34].

The document does not cover connector pinout, electrical levels, strobe or clock timing, polling rate, the Virtual Boy console itself, or the controller's mechanical design.

## Key concepts

- **Strobing.** The action that precedes reading. The document states that after strobing the controller, 16 bits can be read from the data line [L8]. It does not define the strobe signal, its timing, or its pin.
- **Data line.** The single line the 16 bits are read from [L8]. The document does not specify it further.
- **NES-compatible protocol.** The description the document gives of the Virtual Boy controller's protocol [L1].
- **Left D-pad and Right D-pad.** The two directional pads the bit list distinguishes [L14–20].

## Content

### Lead (L1–4)

- The Virtual Boy controller has an NES-compatible protocol, and has been used in homebrew games [L1].
- The lead names two homebrew titles, both in italic markup (`''...''`) [L3–4]:
  - *Spook-O'-Tron* [L3]
  - *Candelabra - Estoscerro* [L4]

### Category tag (L6)

- The wikitext places `[[Category:Controllers]]` at line 6, in the middle of the article body, before the report-format text that follows at line 8 [L6].
- Category tags conventionally sit at the end of a wikitext page. This one does not.

### Report format (L8–26)

- After strobing the controller, the following 16 bits can be read from the data line [L8].
- The document writes the bit list as two indented preformatted blocks separated by a blank line. Both use leading-space MediaWiki `pre` formatting. The first block holds bits 0–7 [L10–17] and the second holds bits 8–15 [L19–26].

### Comparison to other controllers (L28)

- The document states the report is "very analogous to the [[SNES controller]]" [L28]. The SNES controller reports its 4 face buttons where the Virtual Boy reports its right d-pad [L28].
- The document states the last 4 bits (B, A, 1, battery) have no correspondence in the SNES controller report [L28].
- The document states: "Use this 1 to distinguish the Virtual Boy controller from that controller or a [[mouse]]." [L28]. The "1" referred to is the always-1 value at bit 14 [L25, L28].

### References section (L30–34)

- The section heading is `== References ==` [L30].
- The section is a plain bulleted list of four external links. No `<ref>` footnotes, no citation templates, and no inline citation markers appear anywhere in the article [L30–34].

| Reference | Title as printed                                        | Link                                                                                                   | Line |
| --------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ---- |
| 1         | VB Sacred Tech Scroll: Virtual Boy Specifications       | `//web.archive.org/web/20190319100353/perfectkiosk.net/stsvb.html#hardwaregamepad` (protocol-relative) | L31  |
| 2         | PlanetVB: Documents                                     | `https://www.planetvb.com/modules/tech/?sec=docs`                                                      | L32  |
| 3         | Sly Dog Studios: Candelabra - Estoscerro demo available | `https://slydogstudios.org/`                                                                           | L33  |
| 4         | Forum post: Spook-o'-tron - Virtual Boy Controller Fun  | `//forums.nesdev.org/viewtopic.php?f=22&t=15677` (protocol-relative)                                   | L34  |

## Specifications and procedures

### The 16-bit report, verbatim

The document introduces the list with "After strobing the controller, the following 16 bits can be read from the data line:" [L8].

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

- The document states bit 14 is invariant, "Always 1" [L25].
- Bit 15 indicates battery voltage. The document states the polarity as `1 = low voltage` [L26].
- The document states that reading the 16 bits requires strobing the controller first [L8].
- The document states the correspondence with the SNES controller holds only for the first 12 bits. It states the last 4 bits (B, A, 1, battery) have no SNES counterpart [L28].

## Editorial apparatus present in the wikitext

- Internal wikilinks: `[[SNES controller]]` and `[[mouse]]` [L28].
- Category link: `[[Category:Controllers]]` [L6].
- Italic markup on the two game titles: `''Spook-O'-Tron''`, `''Candelabra - Estoscerro''` [L3–4].
- References 1 and 4 use protocol-relative external links (`//host/path`). References 2 and 3 use full `https://` URLs [L31–34].
- Section heading markup: `== References ==` [L30].
- Leading spaces create the preformatted blocks, not `<pre>` tags [L10–26].
- The wikitext contains no template transclusion of any kind, so it has no infobox and no infobox fields to record. No `{{...}}` syntax appears anywhere [L1–34].
- No `<ref>` tags, no `{{reflist}}`, no `<references />` [L1–34].

## Stated gaps and ambiguities

- The article title appears nowhere in the wikitext body. Only the filename carries it.
- The document does not define the strobe signal, clock signal, pin assignments, connector type, voltage levels, or timing. It names only "strobing" and "the data line" [L8].
- The document does not state the shift order of the 16 bits. It gives only the numbering 0 through 15 [L10–26].
- The document does not state whether a set bit means pressed or released for the button bits. It gives the polarity of bit 15 alone, `1 = low voltage` [L26].
- The lead lists two homebrew titles [L3–4], and the text does not connect them to the report format that follows. The document does not say what role the games play beyond having used the controller [L1].
- `[[Category:Controllers]]` sits mid-article at L6 rather than at the end, so the wikitext's structure is irregular. The document gives no explanation [L6].
- The document does not reconcile the claim of an "NES-compatible protocol" [L1] with the 16-bit report length or with the SNES comparison [L28]. It does not state how a 16-bit report relates to the NES protocol.
- The References section lists four sources, and nothing in the body cites any of them. No individual claim in the article carries an attribution to a specific source [L30–34].
- Reference 1 appears only as a Wayback Machine capture of `perfectkiosk.net/stsvb.html`. The document does not state the original page's publication date or author [L31].
