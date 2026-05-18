# FlashCard AI

Generate flashcards automatically from any PDF — powered by a Flutter frontend and a FastAPI backend.

---

## Project structure

```
FlashCardAI/
├── backend/
│   ├── main.py            # FastAPI app
│   └── requirements.txt
└── frontend/
    ├── lib/
    │   └── main.dart      # Flutter app
    ├── macos/Runner/
    │   ├── DebugProfile.entitlements
    │   └── Release.entitlements
    ├── web/
    │   └── index.html
    └── pubspec.yaml
```

---

## 1 — Backend setup

```bash
cd backend

# Create and activate a virtual environment (recommended)
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the server (auto-reloads on file changes)
python main.py
```

The API will be available at **http://localhost:8000**.  
Open **http://localhost:8000/docs** in your browser to explore the Swagger UI.

### Endpoints

| Method | Path          | Description                          |
|--------|---------------|--------------------------------------|
| GET    | `/`           | Health check                         |
| POST   | `/upload-pdf` | Upload a PDF → receive flashcards    |

---

## 2 — Frontend setup

```bash
cd frontend

# Get Flutter packages
flutter pub get

# Run on Chrome (recommended for quick testing)
flutter run -d chrome

# Or run as a macOS desktop app
flutter run -d macos
```

> **Note (macOS desktop):** The entitlement files in `macos/Runner/` grant the app
> sandbox permission to open files and make network requests to localhost.  
> If you scaffolded the project fresh with `flutter create`, those files already
> exist — the ones provided here simply add the required keys.

---

## 3 — Wiring up real AI (optional)

1. Open `backend/main.py`.
2. Replace `"YOUR_OPENAI_API_KEY"` with your actual key (or load it from an
   environment variable).
3. Replace the body of `generate_dummy_cards()` with a real OpenAI call, e.g.:

```python
from openai import OpenAI

client = OpenAI(api_key=OPENAI_API_KEY)

def generate_cards_ai(text: str) -> list[dict]:
    prompt = f"""
    Read the following text and generate 5 concise flashcards.
    Return ONLY a JSON array: [{{"question": "...", "answer": "..."}}, ...]

    TEXT:
    {text[:3000]}
    """
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
    )
    import json
    return json.loads(response.choices[0].message.content)["cards"]
```

---

## Requirements

| Tool    | Version       |
|---------|---------------|
| Python  | 3.9 +         |
| Flutter | 3.22 + (stable)|
| macOS   | 13 + (for desktop target) |
