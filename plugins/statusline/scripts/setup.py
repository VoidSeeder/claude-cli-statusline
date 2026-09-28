#!/usr/bin/env python3
# Grava o statusLine no settings.json do usuário (global) ou do projeto atual.
# Uso:
#   setup.py                              -> ~/.claude/settings.json, mostra o nome da pasta
#   setup.py --projeto "Nome" [--cor 46]  -> ./.claude/settings.local.json, nome em destaque
#   setup.py ... --forcar                 -> substitui um statusLine que já exista
#   setup.py --remover [--projeto ...]    -> remove o statusLine gravado
# Saída 2 = já existe outro statusLine e --forcar não foi passado.
import argparse
import json
import os
import shlex
import shutil
import sys

SCRIPT = "~/.claude/statusline/statusline.sh"
CORES = {"44": "azul acinzentado", "45": "lilás", "46": "azul-água"}

ap = argparse.ArgumentParser()
ap.add_argument("--projeto", help="nome exibido em destaque (grava no projeto atual)")
ap.add_argument("--cor", default="44", choices=sorted(CORES), help="cor de fundo do nome")
ap.add_argument("--forcar", action="store_true")
ap.add_argument("--remover", action="store_true")
args = ap.parse_args()

if args.projeto:
    caminho = os.path.join(os.getcwd(), ".claude", "settings.local.json")
    comando = f"{SCRIPT} {shlex.quote(args.projeto)} {args.cor}"
else:
    caminho = os.path.expanduser("~/.claude/settings.json")
    comando = SCRIPT

try:
    with open(caminho) as f:
        config = json.load(f)
except FileNotFoundError:
    config = {}
except json.JSONDecodeError as e:
    sys.exit(f"{caminho} não é um JSON válido ({e}); corrija antes de rodar o setup.")

atual = config.get("statusLine")
if args.remover:
    if not atual:
        print(f"Nenhum statusLine em {caminho}.")
        sys.exit(0)
    config.pop("statusLine")
else:
    novo = {"type": "command", "command": comando, "refreshInterval": 1}
    if atual == novo:
        print(f"{caminho} já está configurado.")
        sys.exit(0)
    if atual and not args.forcar:
        print(f"{caminho} já tem outro statusLine:\n{json.dumps(atual, indent=2, ensure_ascii=False)}")
        sys.exit(2)
    config["statusLine"] = novo

os.makedirs(os.path.dirname(caminho), exist_ok=True)
if os.path.exists(caminho):
    shutil.copy2(caminho, caminho + ".bak")
tmp = caminho + ".tmp"
with open(tmp, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, caminho)
print(f"statusLine {'removido de' if args.remover else 'gravado em'} {caminho}"
      + (f" (backup em {caminho}.bak)" if os.path.exists(caminho + ".bak") else ""))
