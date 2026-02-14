# Ham Exam Parser

Parses ARRL amateur radio exam question pool files (.docx) into structured JSON, suitable for building quiz and study applications. Supports Technician, General, and Extra class pools.

## Prerequisites

- [Nix](https://nixos.org/download/) package manager
- [direnv](https://direnv.net/) (optional, for automatic environment loading)

The Nix shell provides Ruby 3.3, bundler, and librsvg (for SVG figure conversion). No system-level Ruby or gem installation is needed.

## Setup

```bash
cd ham_exam_parser
direnv allow        # or: nix-shell
bundle install
```

## Usage

```bash
ruby bin/parse_pool --input <pool.docx> [options]
```

### Options

| Flag | Description |
|------|-------------|
| `-i, --input FILE` | Path to .docx question pool file (required) |
| `--images DIR` | Path to directory of figure images |
| `-o, --output FILE` | Output JSON file (default: stdout) |
| `-p, --pretty` | Pretty-print JSON output |
| `--exam-class CLASS` | Exam class (technician, general, extra) |
| `--pool-year YEAR` | Pool year range (e.g., 2022-2026) |

### Example

```bash
ruby bin/parse_pool \
  --input data/technician_2026-2030/pool.docx \
  --images data/technician_2026-2030/figures \
  --pretty \
  --pool-year '2026-2030' \
  --output data/technician_2026-2030/technician_pool.json
```

## Figure handling

Place figure images in a directory and pass it via `--images`. The parser matches figure references in question text (e.g., "Figure T-1", "Figure E5-1") to filenames in the directory. Supported formats: PNG, JPG, GIF, BMP, SVG. SVG files are converted to PNG via `rsvg-convert` before base64 encoding.

## Output format

```json
{
  "exam_class": "technician",
  "pool_year": "2026-2030",
  "subelements": [
    {
      "id": "T1",
      "title": "COMMISSION'S RULES ...",
      "groups": [
        {
          "id": "T1A",
          "title": "Purpose and permissible ...",
          "questions": [
            {
              "id": "T1A01",
              "question": "Which of the following ...",
              "answers": {
                "A": "...",
                "B": "...",
                "C": "...",
                "D": "..."
              },
              "correct_answer": "C",
              "figure": null,
              "figure_image_base64": null
            }
          ]
        }
      ]
    }
  ]
}
```

## Technologies

- **Ruby 3.3** — runtime
- **docx gem** (ruby-docx) — .docx file parsing
- **librsvg** — SVG to PNG conversion for circuit diagrams
- **Nix** — reproducible development environment
- **direnv** — automatic Nix shell activation
