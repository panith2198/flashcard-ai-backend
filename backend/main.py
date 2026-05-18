import io
from typing import List, Dict

import fitz  # PyMuPDF
import uvicorn
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

# ---------------------------------------------------------------------------
# If you later want real AI, replace this key and implement generate_cards_ai()
# ---------------------------------------------------------------------------
OPENAI_API_KEY = "YOUR_OPENAI_API_KEY"

app = FastAPI(title="FlashCard AI Backend")

# Allow all origins so the Flutter web/mobile app can reach the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """Return all text from a PDF given its raw bytes."""
    try:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not open PDF: {exc}")

    text_parts: List[str] = []
    for page in doc:
        text_parts.append(page.get_text())
    doc.close()

    full_text = "\n".join(text_parts).strip()
    if not full_text:
        raise HTTPException(
            status_code=400,
            detail="The PDF appears to contain no extractable text (it may be scanned/image-only).",
        )
    return full_text


def generate_dummy_cards(text: str) -> List[Dict[str, str]]:
    """
    Dummy flashcard generator – no AI call, just returns a fixed set of
    three cards that reference the first 500 characters of the extracted text.
    Swap this function for a real OpenAI call when you're ready.
    """
    snippet = text[:500].replace("\n", " ").strip()

    cards = [
        {
            "question": "Q1: What is the main topic of this document?",
            "answer": f"Based on the opening passage, the document appears to be about: \"{snippet[:120]}…\"",
        },
        {
            "question": "Q2: What key information is introduced at the beginning?",
            "answer": f"The document starts by discussing: \"{snippet[120:300].strip()}…\"",
        },
        {
            "question": "Q3: Summarise the first section in one sentence.",
            "answer": f"The first section covers the following content: \"{snippet[300:500].strip()}\"",
        },
    ]
    return cards


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/")
def root():
    return {"message": "FlashCard AI Backend is running!"}


@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    # ---- validate file type ------------------------------------------------
    if file.content_type not in ("application/pdf", "application/octet-stream"):
        # file_picker on some platforms sends octet-stream, so we accept both.
        # We do a secondary check by filename extension.
        if not (file.filename or "").lower().endswith(".pdf"):
            raise HTTPException(
                status_code=400,
                detail="Only PDF files are accepted. Please upload a valid .pdf file.",
            )

    # ---- read bytes --------------------------------------------------------
    try:
        pdf_bytes = await file.read()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to read uploaded file: {exc}")

    if len(pdf_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    # ---- extract text ------------------------------------------------------
    text = extract_text_from_pdf(pdf_bytes)

    # ---- generate cards (dummy for now) ------------------------------------
    cards = generate_dummy_cards(text)

    return {"status": "success", "cards": cards}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
