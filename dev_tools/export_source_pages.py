from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    import pymupdf as fitz
except ImportError:
    import fitz


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Render selected PDF pages; no OCR, no source edits."
    )
    parser.add_argument("pdf", type=Path)
    parser.add_argument(
        "--pages", type=int, nargs="+", required=True,
        help="1-based PDF page numbers"
    )
    parser.add_argument(
        "--out", type=Path, required=True,
        help="A new output directory"
    )
    args = parser.parse_args()
    pages = sorted(set(args.pages))

    if not args.pdf.is_file():
        parser.error("PDF file not found")
    if not 1 <= len(pages) <= 16:
        parser.error("Select 1 to 16 pages per batch")

    before = sha256(args.pdf)

    with fitz.open(args.pdf) as doc:
        if doc.needs_pass:
            parser.error("Encrypted PDF requires an authorized unlocked copy")
        if any(p < 1 or p > doc.page_count for p in pages):
            parser.error(f"Page numbers must be within 1..{doc.page_count}")

        # Existing output directories are rejected, not overwritten.
        args.out.mkdir(parents=True, exist_ok=False)
        records = []

        for number in pages:
            page = doc.load_page(number - 1)
            png = args.out / f"pdf_page_{number:04d}.png"
            pix = page.get_pixmap(
                matrix=fitz.Matrix(2.5, 2.5), alpha=False
            )
            pix.save(str(png))

            records.append({
                "pdf_page_1_based": number,
                "printed_page": None,
                "figure_id": None,
                "file": png.name,
                "width_px": pix.width,
                "height_px": pix.height,
                "png_sha256": sha256(png),
                "text_layer_excerpt": page.get_text()[:1200],
                "visual_review": "NOT_REVIEWED"
            })

        manifest = {
            "source_filename": args.pdf.name,
            "source_sha256": before,
            "source_page_count": doc.page_count,
            "pages": records
        }

    if sha256(args.pdf) != before:
        raise RuntimeError(
            "Source changed during export; inspect manually, do not overwrite it"
        )

    (args.out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    print(
        f"EXPORTED {len(records)} pages; "
        "source unchanged; visual review pending"
    )


if __name__ == "__main__":
    main()

