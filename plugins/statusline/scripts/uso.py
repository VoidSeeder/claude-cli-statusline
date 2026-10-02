#!/usr/bin/env python3
# Busca o uso da conta (mesma fonte do /status) e grava em cache para a status line.
# Chamado em segundo plano pelo statusline.sh quando o cache passa 60s sem
# atualização; falhas são silenciosas.
import json
import os
import subprocess
import tempfile
import urllib.request

# Perfil ativo: CLAUDE_CONFIG_DIR quando definido, senão ~/.claude. Cada perfil é uma conta,
# então lê as credenciais dele e grava num cache próprio (mesma regra do script da status line).
CONFIG = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
PERFIL = os.path.basename(os.path.normpath(CONFIG)).lstrip(".")
CREDENCIAIS = os.path.join(CONFIG, ".credentials.json")
CACHE = os.path.expanduser(
    "~/.cache/claude-statusline" + ("" if PERFIL == "claude" else "-" + PERFIL) + "/uso.json")
URL = "https://api.anthropic.com/api/oauth/usage"


def ler_credenciais():
    # Linux/WSL guardam o token em arquivo; o macOS guarda no Keychain
    try:
        return json.load(open(CREDENCIAIS))
    except OSError:
        saida = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=5, check=True,
        ).stdout
        return json.loads(saida)


try:
    token = ler_credenciais()["claudeAiOauth"]["accessToken"]
    req = urllib.request.Request(URL, headers={
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
    })
    uso = json.load(urllib.request.urlopen(req, timeout=10))
    # Mesmo formato que o statusline.sh grava a partir das respostas do Claude
    c5, c7 = uso.get("five_hour") or {}, uso.get("seven_day") or {}
    dados = {
        "fonte": "consulta",
        "five_hour": {"pct": c5.get("utilization"), "resets_at": c5.get("resets_at")},
        "seven_day": {"pct": c7.get("utilization"), "resets_at": c7.get("resets_at")},
    }
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    # Escrita atômica para os dois terminais nunca lerem um arquivo pela metade
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE))
    with os.fdopen(fd, "w") as f:
        json.dump(dados, f)
    os.replace(tmp, CACHE)
except Exception:
    pass
