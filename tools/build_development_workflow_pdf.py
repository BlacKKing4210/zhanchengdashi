from __future__ import annotations

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

os.environ.setdefault("DOC_SOURCE_PATH", str(ROOT / "docs" / "DEVELOPMENT_WORKFLOW.md"))
os.environ.setdefault("DOC_OUTPUT_PATH", str(ROOT / "output" / "pdf" / "development-workflow.pdf"))
os.environ.setdefault("DOC_TITLE", "zhanchengdashi development workflow")
os.environ.setdefault("DOC_BREAK_BEFORE_SECTION_ONE", "0")

from build_current_game_module_design_pdf import build_pdf


if __name__ == "__main__":
    build_pdf()
