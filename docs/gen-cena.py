#!/usr/bin/env python3
"""Gera uma imagem com o Gemini (REST). Uso: gen.py <modelo> <saida.png> <prompt-file> [aspect] [imagem-de-referência.png]"""
import sys, json, base64, urllib.request, pathlib
model, out, prompt_file = sys.argv[1], sys.argv[2], sys.argv[3]
aspect = sys.argv[4] if len(sys.argv) > 4 else "3:2"
ref = sys.argv[5] if len(sys.argv) > 5 else None
key = pathlib.Path.home().joinpath(".config/iolcalc/gemini.key").read_text().strip()
prompt = open(prompt_file, encoding="utf-8").read()
parts = [{"text": prompt}]
if ref:
    parts.append({"inline_data": {"mime_type": "image/png", "data": base64.b64encode(open(ref, "rb").read()).decode()}})
body = {"contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": "2K"}}}
req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}",
                             data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
try:
    resp = json.load(urllib.request.urlopen(req, timeout=300))
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:600]); sys.exit(1)
imgs = [p for c in resp.get("candidates", []) for p in c.get("content", {}).get("parts", []) if "inlineData" in p]
if not imgs:
    print("sem imagem:", json.dumps(resp)[:800]); sys.exit(1)
data = base64.b64decode(imgs[0]["inlineData"]["data"])
open(out, "wb").write(data)
print(out, len(data), imgs[0]["inlineData"].get("mimeType"))
