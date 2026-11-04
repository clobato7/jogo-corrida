"""Dá um nome único, por versão, ao pacote do jogo exportado para a web.

O navegador guarda o index.pck no cache e, como o nome era sempre o mesmo,
continuava abrindo a versão antiga mesmo depois de recarregar a página.
Com o nome index-v0.N.pck, cada versão nova obriga o navegador a baixar o pacote novo.
O index.wasm (o motor, ~40 MB) mantém o nome: ele só muda junto com a versão do Godot.

Uso (a Action roda depois de exportar): python3 tools/version_pack.py build/web v0.18
"""
import re
import sys
from pathlib import Path

web = Path(sys.argv[1])
version = sys.argv[2]
new_pck = f"index-{version}.pck"

(web / "index.pck").rename(web / new_pck)

html = web / "index.html"
text = html.read_text(encoding="utf-8")
assert "GODOT_CONFIG = {" in text and '"index.pck"' in text, "formato do index.html mudou"
text = text.replace("GODOT_CONFIG = {", f'GODOT_CONFIG = {{"mainPack":"{new_pck}",', 1)
text = text.replace('"index.pck"', f'"{new_pck}"')
html.write_text(text, encoding="utf-8")

sw = web / "index.service.worker.js"
if sw.exists():
    sw_text = sw.read_text(encoding="utf-8")
    sw.write_text(re.sub(r'"index\.pck"', f'"{new_pck}"', sw_text), encoding="utf-8")

print("Pacote renomeado para", new_pck)
