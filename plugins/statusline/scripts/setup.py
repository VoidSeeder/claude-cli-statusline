#!/usr/bin/env python3
# Grava o statusLine no settings.json do usuário (global) ou do projeto atual.
# Uso:
#   setup.py                              -> ~/.claude/settings.json, mostra o nome da pasta
#   setup.py --projeto "Nome" [--cor 46]  -> ./.claude/settings.local.json, nome em destaque
#   setup.py ... --forcar                 -> substitui um statusLine que já exista
#   setup.py --remover [--projeto ...]    -> remove o statusLine gravado
#   setup.py --verificar                  -> JSON com o estado global e do projeto, e sugestões de nome
# Saída 2 = já existe outro statusLine e --forcar não foi passado.
import argparse
import json
import os
import shlex
import re
import shutil
import subprocess
import sys

SCRIPT = "~/.claude/statusline/statusline.sh"
CORES = {"44": "azul acinzentado", "45": "lilás", "46": "azul-água"}

ap = argparse.ArgumentParser()
ap.add_argument("--projeto", help="nome exibido em destaque (grava no projeto atual)")
ap.add_argument("--cor", default="44", choices=sorted(CORES), help="cor de fundo do nome")
ap.add_argument("--forcar", action="store_true")
ap.add_argument("--remover", action="store_true")
ap.add_argument("--verificar", action="store_true")
args = ap.parse_args()

GLOBAL = os.path.expanduser("~/.claude/settings.json")
LOCAL = os.path.join(os.getcwd(), ".claude", "settings.local.json")


def ler(caminho):
    try:
        with open(caminho) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def git(*cmd):
    try:
        r = subprocess.run(["git", *cmd], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def sugestoes():
    # Nome da raiz do repositório (ou da pasta), o nome do remote e versões legíveis deles
    nomes = [os.path.basename(git("rev-parse", "--show-toplevel") or os.getcwd())]
    remote = git("remote", "get-url", "origin")
    if remote:
        nomes.append(re.sub(r"\.git$", "", remote.rstrip("/")).rsplit("/", 1)[-1].rsplit(":", 1)[-1])
    legiveis = [" ".join(p.capitalize() for p in re.split(r"[-_.\s]+", n) if p) for n in nomes]
    return list(dict.fromkeys(n for n in nomes + legiveis if n))


def estado(atual, esperado):
    if not atual:
        return "ausente"
    comando = atual.get("command", "") if isinstance(atual, dict) else ""
    if esperado(comando):
        return "plugin"
    return "outro"


if args.verificar:
    try:
        glob, local = ler(GLOBAL).get("statusLine"), ler(LOCAL).get("statusLine")
    except json.JSONDecodeError as e:
        sys.exit(f"JSON inválido nas configurações ({e}); corrija antes de rodar o setup.")
    saida = {
        "global": {"caminho": GLOBAL, "estado": estado(glob, lambda c: c == SCRIPT), "atual": glob},
        "projeto": {"caminho": LOCAL, "estado": estado(local, lambda c: c.startswith(SCRIPT + " ")),
                    "atual": local},
        "sugestoes": sugestoes(),
        "cores": CORES,
    }
    if saida["projeto"]["estado"] == "plugin":
        partes = shlex.split(local["command"])[1:]
        saida["projeto"]["nome"] = partes[0] if partes else None
        saida["projeto"]["cor"] = partes[1] if len(partes) > 1 else "44"
    print(json.dumps(saida, indent=2, ensure_ascii=False))
    sys.exit(0)

if args.projeto:
    caminho = LOCAL
    comando = f"{SCRIPT} {shlex.quote(args.projeto)} {args.cor}"
else:
    caminho = GLOBAL
    comando = SCRIPT

try:
    config = ler(caminho)
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
