import os
from typing import List, Dict

import fitz  # PyMuPDF
import uvicorn
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "YOUR_OPENAI_API_KEY")

app = FastAPI(title="FlashCard AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def extract_text_from_pdf(pdf_bytes: bytes) -> str:
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
        raise HTTPException(status_code=400, detail="PDF contains no extractable text.")
    return full_text

def generate_dummy_cards(text: str) -> List[Dict[str, str]]:
    snippet = text[:500].replace("\n", " ").strip()
    return [
        {"question": "Q1: What is the main topic of this document?",
         "answer": f'The document appears to be about: "{snippet[:150]}..."'},
        {"question": "Q2: What key information is introduced at the beginning?",
         "answer": f'The document starts by discussing: "{snippet[150:350].strip()}..."'},
        {"question": "Q3: Summarise the first section in one sentence.",
         "answer": f'The first section covers: "{snippet[350:500].strip()}"'},
    ]

@app.get("/")
def root():
    return {"message": "FlashCard AI Backend is running!"}

@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    if not (file.filename or "").lower().endswith(".pdf"):
        if file.content_type not in ("application/pdf", "application/octet-stream"):
            raise HTTPException(status_code=400, detail="Only PDF files are accepted.")
    try:
        pdf_bytes = await file.read()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {exc}")
    if len(pdf_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")
    text = extract_text_from_pdf(pdf_bytes)
    cards = generate_dummy_cards(text)
    return {"status": "success", "cards": cards}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)
