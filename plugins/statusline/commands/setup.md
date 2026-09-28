---
description: Configura a status line (global ou com o nome do projeto em destaque)
argument-hint: '[remover] | ["Nome do projeto" [44|45|46]]'
allowed-tools: Bash(python3 ~/.claude/statusline/setup.py:*)
---

Configure a status line do plugin rodando `python3 ~/.claude/statusline/setup.py` com os argumentos abaixo, conforme `$ARGUMENTS`:

- Vazio: sem argumentos. Grava no `~/.claude/settings.json` e mostra o nome da pasta.
- Um nome, opcionalmente seguido de uma cor: `--projeto "<nome>" --cor <cor>`. Grava no `.claude/settings.local.json` do projeto atual. Cores: 44 = azul acinzentado (padrão), 45 = lilás, 46 = azul-água.
- `remover`: `--remover`, junto com `--projeto "<nome>"` se um nome também foi passado.

Se `~/.claude/statusline/setup.py` não existir, os scripts ainda não foram sincronizados: peça para o usuário reiniciar o Claude Code (o hook de SessionStart copia os arquivos) e pare.

Se o script sair com código 2, já existe outro `statusLine` configurado. Mostre ao usuário o que existe hoje e só rode de novo com `--forcar` depois que ele confirmar a substituição.

No fim, diga em uma linha onde a configuração foi gravada e que a status line aparece na próxima atualização da interface.
