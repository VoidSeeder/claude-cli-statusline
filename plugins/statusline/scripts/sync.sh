#!/usr/bin/env sh
# Roda no SessionStart: copia os scripts da versão instalada do plugin para um caminho fixo.
# O caminho do plugin muda a cada atualização, e o settings.json precisa de um que não mude.
# Não imprime nada: a saída do SessionStart entraria no contexto da sessão.
origem="$(cd "$(dirname "$0")" && pwd)"
destino="$HOME/.claude/statusline"
mkdir -p "$destino" 2>/dev/null || exit 0
for arq in statusline.sh uso.py setup.py; do
    # Só copia o que mudou, para não reescrever os arquivos a cada sessão
    if ! cmp -s "$origem/$arq" "$destino/$arq"; then
        cp "$origem/$arq" "$destino/$arq.tmp" && chmod +x "$destino/$arq.tmp" \
            && mv "$destino/$arq.tmp" "$destino/$arq"
    fi
done >/dev/null 2>&1
exit 0
