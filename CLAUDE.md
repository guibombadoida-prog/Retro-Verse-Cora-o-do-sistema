# CLAUDE.md

As instruções deste repositório estão em [`AGENTS.md`](AGENTS.md) — leia antes de
mexer em qualquer coisa. Ele é compartilhado com os outros agentes que trabalham
aqui, para que todos sigam o mesmo procedimento.

Os dois pontos que mais causam retrabalho quando são ignorados:

1. **O dono do projeto não tem PC Windows.** Nunca conclua uma entrega pedindo
   que ele cole um script no Roblox Studio. Script novo em `src/` chega ao jogo
   pelo workflow **Publicar somente código**, não pelas mãos dele.
2. **Rode `verificar` antes de `publicar` e leia as listas `+` e `?`.** Um script
   salvo na place com outro nome aparece como novo; publicar sem checar cria uma
   segunda cópia rodando junto com a original.
3. **Consertar bug não é só fazer parar de quebrar.** O script volta com UI que se
   adapta à tela, animação que cancela a anterior em vez de acumular, e física em
   constraint. O projeto tem 58 tweens e nenhum `:Cancel()` — é daí que vem a
   maior parte do que trava e treme na tela. Ver a seção *Padrão de qualidade* do
   `AGENTS.md`.

4. **Código atualizado não é jogo atualizado.** Diga *"código atualizado"* para
   commit, push e PR; diga *"jogo atualizado"* só depois de um `publicar`
   terminar bem. Mesclar PR e rodar `verificar` não mudam o jogo. Quando
   entregar sem publicar, diga que o jogo ainda não mudou — o silêncio é lido
   como "já está no ar".
5. **Publicou, avisou.** Toda publicação vai para o chat com os números do log
   e é registrada em [`docs/PUBLICACOES.md`](docs/PUBLICACOES.md).

Procedimento completo para script novo: [`docs/ADICIONAR_SCRIPT.md`](docs/ADICIONAR_SCRIPT.md).
