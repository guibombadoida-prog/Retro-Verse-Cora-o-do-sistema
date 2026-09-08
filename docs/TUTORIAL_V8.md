# Tutorial V8 — apresentação cinematográfica

Atualiza `TutorialMenuClient_V2` no mesmo destino de produção. Adiciona apenas
o ModuleScript `TutorialPresentation` como dependência local (sem remotes novos).
Mantém as 24 etapas, `_G.OpenTutorialMenu`, `_G.CloseTutorialMenu` e a conclusão
pelo `TutorialSystemServer`. Nenhuma moeda é concedida pelo cliente.

## Comportamento

- Câmera com enquadramentos de personagem/lobby, órbita discreta, FOV suavizado
  e raycast de colisão. Assume somente com personagem vivo na zona segura.
- Devolve câmera/controles ao fechar, pular, morrer, sair do lobby, receber dano,
  teleportar, trocar CurrentCamera, abrir o menu Roblox ou remover/desabilitar a GUI.
- Outro dono de câmera não é sobrescrito. VR e a preferência de movimento
  reduzido desativam a parte cinematográfica; o botão MOV. permite desativá-la.
- Caixa de diálogo com transições canceláveis, progresso, varredura retrô,
  mascote pixelado e molas de botão no toque/mouse/controle.
- Texto completo permanece no TextButton; MaxVisibleGraphemes e utf8.graphemes
  fazem a revelação sem cortar acentos/emojis nem mudar o layout durante a fala.
- Um toque revela a página; o próximo avança. Páginas curtas não são perdidas
  ao girar o aparelho. Voltar, pular e fechar continuam disponíveis.
- Controles de som e velocidade; duas instâncias de Sound reutilizadas.
- Destaque de HUD resolvido pelos objetos reais e ocultado quando o alvo não
  existe, está escondido ou fica atrás do diálogo. Não cria seta num lugar vazio.
- Auto-show espera o fim da LoadingScreen e pode ser cancelado por abertura manual.

## Verificações reproduzíveis

```bash
bash tools/validar.sh
luau tests/TutorialPresentation.spec.luau
python3 tools/test_tutorial.py --luau /caminho/para/luau
rojo build code-payload.project.json --output build/RetroVerse-code-payload.rbxm
```

O harness executa o LocalScript real com dublês de serviços. Ele testa inicialização,
sequenciamento, posse da câmera, navegação e limpeza. Não é uma captura do Roblox:
proporções visuais, áudio e colisão real ainda precisam de teste no cliente do jogo.
O CFrame do harness é simplificado e o utf8.graphemes é substituído por codepoints;
a implementação de produção usa o segmentador Unicode nativo do Roblox.

## Publicação

O pacote esperado altera `TutorialMenuClient_V2` e cria `TutorialPresentation`.
Antes de publicar, conferir os `+`/`?` da execução `verificar` para evitar
duplicatas e alterações alheias. Só avisar **jogo atualizado** depois da linha
`[PUBLICAÇÃO]`, registrada em `docs/PUBLICACOES.md`.

## Referências de API

- [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera)
- [TextLabel / MaxVisibleGraphemes](https://create.roblox.com/docs/reference/engine/classes/TextLabel)
- [utf8.graphemes](https://create.roblox.com/docs/reference/engine/libraries/utf8)
- [GuiService / ReducedMotionEnabled](https://create.roblox.com/docs/reference/engine/classes/GuiService)
