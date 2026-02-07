from fastapi import FastAPI
from pydantic import BaseModel
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

app = FastAPI()

# ===== LOAD 1 LẦN =====
tokenizer = AutoTokenizer.from_pretrained("vinai/phobert-base")
model = AutoModelForSequenceClassification.from_pretrained(
    "./model/chat_moderation_model_v3"
)
model.eval()

LABEL_MAP = {
    0: "grooming",
    1: "hate_or_threat",
    2: "insult",
    3: "normal",
    4: "scam",
    5: "sexual"
}

class Req(BaseModel):
    text: str

@app.post("/moderate")
def moderate(req: Req):
    inputs = tokenizer(
        req.text,
        return_tensors="pt",
        truncation=True,
        max_length=256
    )

    with torch.no_grad():
        logits = model(**inputs).logits
        probs = torch.softmax(logits, dim=-1)

    label_id = torch.argmax(probs).item()

    return {
        "label": LABEL_MAP[label_id],
        "score": float(probs[0][label_id])
    }
