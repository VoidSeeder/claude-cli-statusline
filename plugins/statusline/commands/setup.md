---
description: Configura a status line (global ou com o nome do projeto em destaque)
argument-hint: '[remover] | ["Nome do projeto" [44|45|46]]'
allowed-tools: Bash(python3 ~/.claude/statusline/setup.py:*), AskUserQuestion
---

A status line é configurada rodando `python3 ~/.claude/statusline/setup.py`. Se esse arquivo não existir, os scripts ainda não foram sincronizados: peça para o usuário reiniciar o Claude Code (o hook de SessionStart copia os arquivos) e pare.

Em qualquer etapa, se o script sair com código 2, já existe outro `statusLine` no arquivo. Mostre ao usuário o que existe hoje e só rode de novo com `--forcar` depois que ele confirmar a substituição.

## Atalhos com argumentos

Se `$ARGUMENTS` não estiver vazio, pule o fluxo guiado e rode direto:

- Um nome, opcionalmente seguido de uma cor: `--projeto "<nome>" --cor <cor>`. Grava no `.claude/settings.local.json` do projeto atual.
- `remover`: `--remover`, junto com `--projeto "<nome>"` se um nome também foi passado.

## Fluxo guiado (sem argumentos)

1. Rode `setup.py --verificar`. Ele imprime um JSON com:
   - `global.estado` e `projeto.estado`: `plugin` (já configurado por este plugin), `outro` (existe outro `statusLine`) ou `ausente`;
   - `projeto.nome` e `projeto.cor`, quando o projeto já está configurado;
   - `sugestoes`: nomes possíveis para o projeto;
   - `cores`: as cores de fundo disponíveis.

2. **Setup global.** Se `global.estado` não for `plugin`, o setup global ainda não foi feito. Pergunte com `AskUserQuestion` se o usuário quer fazê-lo agora, explicando que ele grava em `~/.claude/settings.json` e mostra o nome da pasta em todos os projetos (se o estado for `outro`, avise que o `statusLine` atual será substituído). Se ele confirmar, rode `setup.py` sem argumentos (com `--forcar` se o estado era `outro`, já que a confirmação foi dada) e siga para o passo 3. Se ele recusar, pare aqui.

3. **Setup do projeto.** Com o setup global feito (`global.estado` era `plugin` ou acabou de ser gravado no passo 2), guie o usuário para destacar o nome do projeto atual, com uma única chamada de `AskUserQuestion` com duas perguntas:
   - **Nome**: até 3 opções tiradas de `sugestoes`, com a mais legível (a versão com espaços e maiúsculas) primeiro e marcada como recomendada. Se o projeto já estiver configurado, a primeira opção é o nome atual (`projeto.nome`), marcada como "atual". O usuário pode digitar outro nome em "Other".
   - **Cor**: as três cores de `cores`, com o código e o nome (ex.: "Lilás (45)"). Se o projeto já estiver configurado, a cor atual vem primeiro, marcada como "atual"; senão, `44` vem primeiro, marcada como recomendada.

   Com as respostas, rode `setup.py --projeto "<nome>" --cor <cor>`. Se `projeto.estado` já era `plugin` com o mesmo nome e cor, só diga que nada mudou.

No fim, diga em uma linha onde cada configuração foi gravada e que a status line aparece na próxima atualização da interface.
