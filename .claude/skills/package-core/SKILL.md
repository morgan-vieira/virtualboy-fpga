---
name: package-core
description: Package the openFPGA Virtual Boy core into an installable Analogue Pocket .zip, including compiling the Quartus bitstream, converting the RBF to the bit-reversed RBF_R format APF requires, staging the SD-card folder tree (/Cores, /Platforms, /Assets), naming the archive per Analogue's convention, and verifying the result. Use when an agent needs to build a release zip, refresh bitstream.rbf_r after a Quartus compile, or check that a packaged core matches core.json metadata.
---

# Package Core

Produce one installable release archive that a user extracts onto the root of a Pocket SD card.

Treat [docs/analogue/packaging-a-core.md](../../../docs/analogue/packaging-a-core.md) and [docs/analogue/directories-and-sd-folder-structure.md](../../../docs/analogue/directories-and-sd-folder-structure.md) as the authoritative format reference when this skill and the docs disagree.

## Derive every name from core.json

Read `core.json` at the repository root before creating any files. Derive names from its metadata rather than assuming them:

- The core folder name is `<author>.<shortname>`, currently `MorganVieira.VirtualBoy`. It must match `metadata.author` and `metadata.shortname` exactly.
- The archive name is `<author>.<shortname>_<version>_<date_release>.zip`, currently `MorganVieira.VirtualBoy_0.1.0_2026-08-09.zip`.
- The bitstream filename inside the core folder must match `cores[].filename`, currently `bitstream.rbf_r`.

When cutting a new release, bump `metadata.version` and set `metadata.date_release` before packaging so the archive name and the JSON agree.

## Compile the bitstream

Reuse an existing compiled bitstream when the FPGA sources have not changed since it was produced. Do not recompile merely to package.

Otherwise run the compile from the repository root as its own command:

```bash
quartus_sh --flow compile src/fpga/ap_core.qpf
```

Do not chain a `cd` earlier in the same shell command as the Quartus invocation; the compile silently resolves against the changed directory and writes output to the wrong place.

On morgan-vieira's machine this is Quartus Prime Lite 21.1, installed at `C:\intelFPGA_lite\21.1` with `quartus\bin64` on the user `PATH`. Confirm both rather than assuming them on another machine.

A successful compile writes `src/fpga/output_files/ap_core.rbf`. If Quartus is unavailable on the host, report the missing tool rather than packaging a stale bitstream as current.

`ap_core.sof` is a JTAG debugging artifact. Never package it.

## Convert RBF to RBF_R

APF loads a bit-reversed RBF, where every byte has its bits swapped 7:0 to 0:7. Convert the compiled bitstream:

```bash
python -c "
import pathlib
data = pathlib.Path('src/fpga/output_files/ap_core.rbf').read_bytes()
rev = bytes(int(format(b, '08b')[::-1], 2) for b in data)
pathlib.Path('output/bitstream.rbf_r').write_bytes(rev)
print(f'Reversed {len(data)} bytes')
"
```

The output must be exactly the same size as the input. Bit reversal is its own inverse; to confirm a suspect conversion, reverse the file a second time and compare it byte-for-byte against the original RBF.

## Stage one clean SD-card tree

Build the archive contents in a fresh staging directory created for this run. The archive may contain only base folders the Pocket itself creates, such as `Cores`, `Platforms`, and `Assets`. Never include repository files that do not ship on the SD card.

- Copy `core.json`, `audio.json`, `data.json`, `input.json`, `interact.json`, `variants.json`, `video.json`, and `info.txt` from the repository root into `Cores/MorganVieira.VirtualBoy/`.
- Copy `output/bitstream.rbf_r` into `Cores/MorganVieira.VirtualBoy/`.
- Copy `dist/icon.bin` into `Cores/MorganVieira.VirtualBoy/`.
- Copy `dist/platforms/virtualboy.json` into `Platforms/`.
- Copy `dist/platforms/_images/virtualboy.bin` into `Platforms/_images/`.
- Copy the contents of `dist/assets/virtualboy/common/` into `Assets/virtualboy/common/` only when it contains real asset files.

Both platform filenames are the platform id from `core.json`'s `metadata.platform_ids`, currently `virtualboy`. The Pocket matches them by name, so a renamed platform id renames both files.

Never copy `.gitkeep` or `.keep` placeholder files into the archive.

```bash
STAGE=$(mktemp -d)
CORE="$STAGE/Cores/MorganVieira.VirtualBoy"
mkdir -p "$CORE" "$STAGE/Platforms/_images"
cp core.json audio.json data.json input.json interact.json variants.json video.json info.txt "$CORE/"
cp output/bitstream.rbf_r dist/icon.bin "$CORE/"
cp dist/platforms/virtualboy.json "$STAGE/Platforms/"
cp dist/platforms/_images/virtualboy.bin "$STAGE/Platforms/_images/"
```

## Create the archive

Name the archive from `core.json` metadata, and write paths relative to the staging directory so the base folders sit at the archive root rather than inside a nested folder.

There is no `zip` on the Windows host, so build the archive with Python, which is already needed for the bit reversal:

```bash
VERSION=$(python -c "import json;print(json.load(open('core.json'))['core']['metadata']['version'])")
DATE=$(python -c "import json;print(json.load(open('core.json'))['core']['metadata']['date_release'])")
python -c "
import pathlib, sys, zipfile
stage = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(sys.argv[2], 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(stage.rglob('*')):
        if p.is_file():
            z.write(p, p.relative_to(stage).as_posix())
" "$STAGE" "output/MorganVieira.VirtualBoy_${VERSION}_${DATE}.zip"
```

Write the finished archive to `output/`; it is gitignored for generated artifacts.

## Verify and finish

Do not report a release as ready until every check passes:

1. The top level contains only Pocket base folders, every staged path is present, and no `.keep`, `.sof`, or plain `.rbf` files appear.
2. `bitstream.rbf_r` in the archive is the same size as `src/fpga/output_files/ap_core.rbf`.
3. The archive filename's author, shortname, version, and date match `core.json`.
4. Every `.json` in the archive parses.

Read the members straight out of the zip rather than extracting; `unzip -l` shows the listing, and this checks all four:

```bash
python -c "
import json, pathlib, sys, zipfile
archive = pathlib.Path(sys.argv[1])
z = zipfile.ZipFile(archive)
top = {n.split('/')[0] for n in z.namelist()}
assert top <= {'Cores', 'Platforms', 'Assets'}, f'stray top-level entries: {top}'
stray = [n for n in z.namelist() if n.endswith(('.keep', '.gitkeep', '.sof', '.rbf'))]
assert not stray, f'files that must not ship: {stray}'
rbf = pathlib.Path('src/fpga/output_files/ap_core.rbf').stat().st_size
packed = z.getinfo('Cores/MorganVieira.VirtualBoy/bitstream.rbf_r').file_size
assert packed == rbf, f'bitstream is {packed} bytes, compiled rbf is {rbf}'
meta = json.loads(z.read('Cores/MorganVieira.VirtualBoy/core.json'))['core']['metadata']
want = f\"{meta['author']}.{meta['shortname']}_{meta['version']}_{meta['date_release']}.zip\"
assert want == archive.name, f'archive should be named {want}'
for name in z.namelist():
    if name.endswith('.json'):
        json.loads(z.read(name))
print(f'{archive.name}: all four checks pass')
" "output/MorganVieira.VirtualBoy_${VERSION}_${DATE}.zip"
```

Remove only the staging directory created for this run.

To install for testing, extract the archive onto the SD card root. The SD card mounts through a removable USB3 reader, so its drive letter moves between sessions; confirm the current drive letter rather than assuming a previous one.

## Troubleshoot predictable failures

- **The archive extracts into a nested folder:** the entries were written with their full staging paths. Every archive path must be relative to the staging directory, so the first component is `Cores`, `Platforms`, or `Assets`.
- **The Pocket does not list the core:** verify the core folder is named exactly `<metadata.author>.<metadata.shortname>` and that every `.json` in the archive parses.
- **The core lists but fails to boot:** the packaged bitstream is likely a plain `.rbf`. Confirm it was bit-reversed and matches the compiled `.rbf` size.
- **`quartus_sh: command not found` on a machine where Quartus is installed:** Windows hands a process its environment at launch, so a shell older than the `PATH` entry never sees it. Check `HKCU:\Environment` for the real value; if the entry is there, call `C:\intelFPGA_lite\21.1\quartus\bin64\quartus_sh.exe` by full path for this session rather than reporting Quartus missing.
- **The compile produced no `.rbf`:** verify the compile ran from the repository root without a preceding `cd`, and that the Quartus project has "Raw Binary File (.rbf)" checked under "Assignments > Device > Device and Pin Options > Programming Files" with output directory `output_files`.
