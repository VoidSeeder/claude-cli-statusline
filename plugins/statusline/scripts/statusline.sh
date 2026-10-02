#!/usr/bin/env bash
# Status line do Claude CLI com o nome do projeto em destaque.
# Uso: statusline.sh ["<Nome>" <cor_fundo_ansi>]   (ex.: 46 = ciano, 45 = magenta)
# Sem argumentos (configuração global), mostra o nome da pasta, sem destaque de cor.
nome="$1"
cor="${2:-44}"

# Paleta pastel (truecolor). Cores de fundo do nome: 45 = magenta, 46 = ciano
case "$cor" in
    45) cor_nome='48;2;216;180;226' ;;   # lilás
    46) cor_nome='48;2;166;216;222' ;;   # azul-água
    *)  cor_nome='48;2;190;200;230' ;;   # azul acinzentado
esac
VERDE='38;2;168;226;163'
AZUL='38;2;160;196;236'
AMARELO='38;2;240;224;150'
LARANJA='38;2;246;190;150'
VERMELHO='38;2;240;160;160'
LAVANDA='38;2;200;184;242'
DOURADO='38;2;232;206;140'
input=$(cat)
# Pasta deste script: o uso.py fica ao lado dele
export STATUSLINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extrai do JSON recebido via stdin: modelo, effort, tamanho do contexto (em k tokens), total de
# tokens gastos na conversa,
# % dos limites de 5h (sessão) e 7 dias (semanal) e horários de reset de ambos.
# Os limites ficam num cache compartilhado entre os terminais, sempre com o dado mais recente:
#   - cada resposta nova do Claude (em qualquer sessão/terminal) grava os limites dela no cache;
#   - se o cache passar 60s sem atualização, consulta a mesma fonte do /status em segundo
#     plano (uso.py).
# Campos ausentes viram -1 (números) ou "-" (textos).
IFS=$'\t' read -r modelo effort ctxk gastos pct5h reset5h pct7d reset7d dir_projeto dir_atual < <(python3 -c '
import sys, json, os, time, tempfile, subprocess
from datetime import datetime
try:
    d = json.loads(sys.stdin.read() or "{}")
except Exception:
    d = {}

# Cada perfil (CLAUDE_CONFIG_DIR) é uma conta com limites próprios: cache separado por perfil
PERFIL = os.path.basename(os.path.normpath(os.environ.get("CLAUDE_CONFIG_DIR") or ".claude")).lstrip(".")
DIR = os.path.expanduser("~/.cache/claude-statusline" + ("" if PERFIL == "claude" else "-" + PERFIL))
CACHE = os.path.join(DIR, "uso.json")
TRAVA = CACHE + ".buscando"
BUSCA = os.path.join(os.environ["STATUSLINE_DIR"], "uso.py")

def idade(caminho):
    try:
        return time.time() - os.path.getmtime(caminho)
    except OSError:
        return float("inf")

def gravar(caminho, conteudo):
    # Escrita atômica para os terminais nunca lerem um arquivo pela metade
    os.makedirs(DIR, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=DIR)
    with os.fdopen(fd, "w") as f:
        f.write(conteudo)
    os.replace(tmp, caminho)

# 1) Resposta nova do Claude: grava os limites dela no cache.
# O mesmo JSON chega de novo a cada refresh de 1s, e sessões paradas carregam limites
# antigos. Por isso só conta como resposta nova quando o tempo total de API da sessão
# aumentou desde a última vez que este script a viu. Na primeira vez que uma sessão
# aparece, só registra o ponto de partida, sem mexer no cache.
rl = d.get("rate_limits") or {}
h5_in, d7_in = rl.get("five_hour") or {}, rl.get("seven_day") or {}
if h5_in.get("used_percentage") is not None or d7_in.get("used_percentage") is not None:
    duracao = (d.get("cost") or {}).get("total_api_duration_ms") or 0
    arq_sessao = os.path.join(DIR, "sessao-" + str(d.get("session_id") or "sem-sessao"))
    try:
        anterior = float(open(arq_sessao).read())
    except (OSError, ValueError):
        anterior = None
    try:
        if anterior is not None and duracao > anterior:
            gravar(CACHE, json.dumps({
                "fonte": "resposta",
                "five_hour": {"pct": h5_in.get("used_percentage"), "resets_at": h5_in.get("resets_at")},
                "seven_day": {"pct": d7_in.get("used_percentage"), "resets_at": d7_in.get("resets_at")},
            }))
        if anterior is None or duracao > anterior:
            gravar(arq_sessao, str(duracao))
            # Limpa registros de sessões sem atividade há mais de 2 dias
            for nome_arq in os.listdir(DIR):
                if nome_arq.startswith(("sessao-", "tokens-")) and idade(os.path.join(DIR, nome_arq)) > 2 * 86400:
                    os.remove(os.path.join(DIR, nome_arq))
    except Exception:
        pass

# 2) Cache sem atualização há mais de 60s: consulta ativa em segundo plano,
# no máximo uma a cada 30s (a trava evita consultas duplicadas entre os terminais)
if idade(CACHE) > 60 and idade(TRAVA) > 30:
    try:
        os.makedirs(DIR, exist_ok=True)
        open(TRAVA, "w").close()
        subprocess.Popen([sys.executable, BUSCA], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def pct_int(v):
    return int(v) if v is not None else -1

def hora(ts, formato="%H:%M"):
    if not ts:
        return "-"
    if isinstance(ts, str):
        ts = datetime.fromisoformat(ts).timestamp()
    # Arredonda para o minuto mais próximo (o servidor às vezes manda hh:29:59.9)
    return datetime.fromtimestamp(round(ts / 60) * 60).strftime(formato)


modelo = ((d.get("model") or {}).get("display_name") or "?")
# Effort: só vem quando o modelo suporta
effort = ((d.get("effort") or {}).get("level") or "-")

tokens = (d.get("context_window") or {}).get("total_input_tokens") or 0
ctxk = round(tokens / 1000)

# Tokens gastos na conversa: soma o usage de cada resposta registrada no transcript
# (incluindo subagentes). A leitura é incremental: guarda até onde cada arquivo foi lido
# e os ids já somados (uma mesma resposta aparece em várias linhas).
def tokens_gastos():
    transcript = d.get("transcript_path")
    if not transcript:
        return 0
    sessao = os.path.splitext(os.path.basename(transcript))[0]
    arq_cache = os.path.join(DIR, "tokens-" + sessao)
    try:
        estado = json.load(open(arq_cache))
    except Exception:
        estado = {"offsets": {}, "ids": [], "total": 0}
    ids = set(estado["ids"])
    mudou = False
    pasta_sub = os.path.join(os.path.dirname(transcript), sessao, "subagents")
    try:
        subs = [os.path.join(pasta_sub, n) for n in os.listdir(pasta_sub) if n.endswith(".jsonl")]
    except OSError:
        subs = []
    for arq in [transcript] + subs:
        offset = estado["offsets"].get(arq, 0)
        try:
            if os.path.getsize(arq) <= offset:
                continue
            with open(arq, "rb") as f:
                f.seek(offset)
                bloco = f.read()
        except OSError:
            continue
        # Só consome até a última linha completa (a última pode estar sendo escrita)
        fim = bloco.rfind(b"\n") + 1
        for linha in bloco[:fim].splitlines():
            if b"\"usage\"" not in linha:
                continue
            try:
                m = json.loads(linha).get("message") or {}
                u, mid = m.get("usage") or {}, m.get("id")
            except Exception:
                continue
            if not u or not mid or mid in ids:
                continue
            ids.add(mid)
            estado["total"] += sum(u.get(k) or 0 for k in ("input_tokens", "cache_creation_input_tokens",
                                                           "cache_read_input_tokens", "output_tokens"))
        estado["offsets"][arq] = offset + fim
        mudou = True
    if mudou:
        estado["ids"] = list(ids)
        try:
            gravar(arq_cache, json.dumps(estado))
        except Exception:
            pass
    return estado["total"]

try:
    gastos = tokens_gastos()
except Exception:
    gastos = 0

# 3) Exibe o que está no cache; sem cache, usa os dados da resposta atual
try:
    uso = json.load(open(CACHE))
    h5, d7 = uso.get("five_hour") or {}, uso.get("seven_day") or {}
except Exception:
    h5 = {"pct": h5_in.get("used_percentage"), "resets_at": h5_in.get("resets_at")}
    d7 = {"pct": d7_in.get("used_percentage"), "resets_at": d7_in.get("resets_at")}

try:
    reset5h = hora(h5.get("resets_at"))
except Exception:
    reset5h = "-"
try:
    reset7d = hora(d7.get("resets_at"), "%d/%m")  # só a data (ex.: "02/10")
except Exception:
    reset7d = "-"

ws = d.get("workspace") or {}
dir_atual = ws.get("current_dir") or d.get("cwd") or os.getcwd()
dir_projeto = ws.get("project_dir") or dir_atual

print("\t".join(str(v) for v in (modelo, effort, ctxk, gastos, pct_int(h5.get("pct")), reset5h,
                                  pct_int(d7.get("pct")), reset7d, dir_projeto, dir_atual)))
' <<< "$input")

# Verde abaixo de 50%, amarelo até 79%, vermelho a partir de 80%
cor_pct() {
    if [ "$1" -ge 80 ]; then echo "$VERMELHO"; elif [ "$1" -ge 50 ]; then echo "$AMARELO"; else echo "$VERDE"; fi
}

# Cor do tamanho do contexto (em k tokens), com teto desejado de 150k
cor_ctx() {
    if   [ "$1" -ge 150 ]; then echo "1;38;2;230;230;230;48;2;200;60;60"  # texto branco em fundo vermelho: passou do teto
    elif [ "$1" -ge 120 ]; then echo "1;$VERMELHO"
    elif [ "$1" -ge 90 ];  then echo "1;$LARANJA"
    elif [ "$1" -ge 60 ];  then echo "1;$AMARELO"
    elif [ "$1" -ge 30 ];  then echo "1;$AZUL"
    else                        echo "1;$VERDE"
    fi
}

# Só exibe a branch se a pasta atual for um repositório git
branch=$(git -C "$dir_atual" branch --show-current 2>/dev/null)

# Lado esquerdo: projeto (nome definido, com fundo colorido; ou nome da pasta) e branch
if [ -n "$nome" ]; then
    printf -v esquerda '\033[1;30;%sm  %s  \033[0m' "$cor_nome" "$nome"
else
    printf -v esquerda '\033[1m%s\033[0m' "$(basename "$dir_projeto")"
fi
[ -n "$branch" ] && printf -v esquerda '%s  \033[2m⎇ %s\033[0m' "$esquerda" "$branch"

# Modelo: fica centralizado no espaço entre os dois lados
printf -v txt_modelo '\033[1m%s\033[0m' "$modelo"
# Effort ao lado do modelo, sem rótulo: a cor indica o nível
case "$effort" in
    low)    cor_effort="1;$VERDE" ;;
    medium) cor_effort="1;$AZUL" ;;
    high)   cor_effort="1;$AMARELO" ;;
    xhigh)  cor_effort="1;$VERMELHO"; effort='xHigh' ;;
    max)    cor_effort='1;38;2;230;230;230;48;2;200;60;60'; effort=' max ' ;;  # texto branco em fundo vermelho
    *)      cor_effort='1' ;;
esac
[ "$effort" != "-" ] && printf -v txt_modelo '%s \033[%sm%s\033[0m' "$txt_modelo" "$cor_effort" "$effort"

# Lado direito: contexto, tokens gastos e limites de uso
# Acima do teto, o fundo vermelho ganha um espaço de cada lado para o texto não colar na borda
ctx_pad=''; [ "$ctxk" -ge 150 ] && ctx_pad=' '
printf -v direita '📄 \033[%sm%s%sk%s\033[0m' "$(cor_ctx "$ctxk")" "$ctx_pad" "$ctxk" "$ctx_pad"
# Tokens gastos na conversa (em k, ou M a partir de 1 milhão); começa em 0k, como o contexto
if [ "$gastos" -ge 1000000 ]; then
    gastos_fmt="$(( gastos / 1000000 )).$(( gastos % 1000000 / 100000 ))M"
else
    gastos_fmt="$(( (gastos + 500) / 1000 ))k"
fi
printf -v direita '%s 💰 \033[1;%sm%s\033[0m' "$direita" "$DOURADO" "$gastos_fmt"
# Limites de uso do plano (só vêm em assinaturas Pro/Max, após a 1ª resposta)
if [ "$pct5h" -ge 0 ]; then
    printf -v direita '%s  ⏳ \033[%sm%s%%\033[0m' "$direita" "$(cor_pct "$pct5h")" "$pct5h"
    [ "$reset5h" != "-" ] && printf -v direita '%s 🔄 \033[1;%sm%s\033[0m' "$direita" "$LAVANDA" "$reset5h"
fi
if [ "$pct7d" -ge 0 ]; then
    printf -v direita '%s  📅 \033[%sm%s%%\033[0m' "$direita" "$(cor_pct "$pct7d")" "$pct7d"
    [ "$reset7d" != "-" ] && printf -v direita '%s 🔄 \033[1;%sm%s\033[0m' "$direita" "$LAVANDA" "$reset7d"
fi

# Espaço entre os lados para encostar o direito na borda. O Claude informa a largura do
# terminal em $COLUMNS; MARGEM desconta o recuo que a própria interface do Claude adiciona.
MARGEM=4
largura() {
    # Largura visível: ignora códigos de cor e conta emojis como 2 colunas
    python3 -c '
import sys, re, unicodedata
t = re.sub(r"\x1b\[[0-9;]*m", "", sys.argv[1])
print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in t))
' "$1"
}
# Numa linha só, o modelo fica no meio do espaço entre a branch e o contexto. Se não couber
# (com pelo menos 2 espaços de cada lado do modelo), o modelo e o lado direito descem para uma
# segunda linha, encostados na borda. Como o script roda a cada refresh com o $COLUMNS atual,
# o layout acompanha o redimensionamento da janela.
direita2="$txt_modelo  $direita"
if [ -z "$COLUMNS" ]; then
    printf '%s  %s' "$esquerda" "$direita2"
    exit 0
fi
util=$(( COLUMNS - MARGEM ))
livre=$(( util - $(largura "$esquerda") - $(largura "$txt_modelo") - $(largura "$direita") ))
if [ "$livre" -ge 4 ]; then
    antes=$(( livre / 2 ))
    printf '%s%*s%s%*s%s' "$esquerda" "$antes" '' "$txt_modelo" "$(( livre - antes ))" '' "$direita"
else
    recuo=$(( util - $(largura "$direita2") )); [ "$recuo" -lt 0 ] && recuo=0
    printf '%s\n%*s%s' "$esquerda" "$recuo" '' "$direita2"
fi
