# claude-cli-statusline

Status line para o [Claude Code](https://code.claude.com) com cores pastel. Mostra:

- nome do projeto (ou da pasta) e a branch do git
- modelo em uso e, ao lado, o effort, com cor por nível: verde (low), azul (medium), amarelo (high), vermelho (xHigh) e texto branco em fundo vermelho (max)
- 📄 tamanho do contexto em k tokens, com cores que esquentam até o teto de 150k
- 💰 total de tokens gastos na conversa atual (entrada, cache e saída, incluindo subagentes)
- uso dos limites de 5 horas e 7 dias do plano, com o horário de reset de cada um

Os limites ficam num cache compartilhado entre os terminais abertos, então todos mostram o dado mais recente.

## Instalação

No Claude Code:

```
/plugin marketplace add voidseeder/claude-cli-statusline
/plugin install statusline@voidseeder
```

Reinicie o Claude Code (o hook de início de sessão copia os scripts para `~/.claude/statusline/`) e rode:

```
/statusline:setup
```

Na primeira vez, ele oferece o setup global (grava em `~/.claude/settings.json` e mostra o nome da pasta em todos os projetos) e, em seguida, o do projeto atual.

### Nome do projeto em destaque

Com o setup global feito, `/statusline:setup` dentro da pasta do projeto sugere nomes (a partir da pasta e do remote do git) e pergunta a cor de fundo: `44` azul acinzentado (padrão), `45` lilás, `46` azul-água. Isso grava em `.claude/settings.local.json`.

Para pular as perguntas:

```
/statusline:setup "Meu Projeto" 45
```

### Remover

```
/statusline:setup remover
```

Depois, `/plugin uninstall statusline@voidseeder`.

## Requisitos

- `bash` e `python3` no PATH
- Terminal com truecolor
- Os limites de uso só aparecem em assinaturas Pro/Max

## Como funciona

- O Claude Code manda os dados da sessão em JSON para o `statusline.sh`, que monta a linha.
- A cada resposta nova, os limites que vieram nela são gravados em `~/.cache/claude-statusline/uso.json`.
- Se o cache passa 60s sem atualização, o `uso.py` consulta em segundo plano o mesmo endpoint que o `/status` usa, no máximo uma vez a cada 30s.
- A cada início de sessão, `sync.sh` copia os scripts da versão instalada do plugin para `~/.claude/statusline/`. O caminho do plugin muda a cada atualização, e o `settings.json` precisa apontar para um caminho fixo.

## Limitações

- A consulta ativa usa `api.anthropic.com/api/oauth/usage`, que **não é uma API pública documentada** e pode mudar sem aviso. Se falhar, a status line continua funcionando só com os dados que chegam nas respostas.
- O token é lido de `~/.claude/.credentials.json` (Linux/WSL) ou do Keychain do macOS. Ele só é enviado para `api.anthropic.com`.
- Os rótulos e comentários estão em português.

## Licença

MIT
