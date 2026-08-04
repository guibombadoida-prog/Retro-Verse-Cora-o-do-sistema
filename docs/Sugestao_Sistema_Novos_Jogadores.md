# Sugestão — Sistema de Jornada do Recruta

## Objetivo

Atrair e reter novos jogadores com uma progressão inicial clara, curta e recompensadora,
sem remover a liberdade de explorar o RetroVerse. A ideia é transformar os primeiros
30 a 45 minutos em uma sequência de metas simples que ensina combate, personagens,
missões, passivas, chefões e socialização.

## Conceito central

O jogador novo recebe o status temporário de **Recruta Retro**. Durante esse período,
um painel chamado **Jornada do Recruta** mostra capítulos com objetivos pequenos,
recompensas imediatas e prévias visuais do que será liberado depois.

O sistema deve funcionar como uma trilha opcional, mas muito visível:

1. **Chegada ao Lobby** — escolher personagem inicial, entender vida e energia.
2. **Primeiro Combate** — derrotar NPCs fracos com indicação de alvo.
3. **Primeira Evolução** — subir nível do personagem e ver o aumento de atributos.
4. **Primeira Passiva** — equipar uma passiva recomendada.
5. **Primeira Missão Real** — completar uma missão curta com recompensa de moedas.
6. **Primeiro Evento Social** — entrar em time, duelo amistoso ou fila de boss fácil.
7. **Formatura Retro** — receber título cosmético e liberar missões diárias avançadas.

## Por que atrai jogadores novos

- Dá direção sem depender de tutorial longo.
- Entrega recompensas rápidas nos primeiros minutos.
- Mostra sistemas profundos aos poucos, evitando sobrecarga.
- Incentiva o jogador a experimentar combate, progressão e socialização.
- Cria sensação de pertencimento com título, efeitos simples e marco de formatura.

## Recompensas sugeridas

| Capítulo | Recompensa |
|---|---|
| Chegada ao Lobby | 100 moedas + badge de boas-vindas |
| Primeiro Combate | XP de personagem + efeito visual curto |
| Primeira Evolução | Caixa de item comum ou fragmentos |
| Primeira Passiva | Passiva inicial gratuita ou desconto |
| Primeira Missão Real | Moedas + progresso de conquista |
| Primeiro Evento Social | Bônus de XP temporário em grupo |
| Formatura Retro | Título `Recruta Formado` + moldura simples no perfil |

## Integração com sistemas atuais

- **TutorialSystem**: controla os passos iniciais e pode marcar capítulos concluídos.
- **MissionSystem**: reaproveita objetivos como derrotar NPCs, ganhar moedas e completar ações.
- **CharacterLevel**: fornece metas de nível por personagem.
- **PassiveSystem**: guia o jogador até a primeira passiva.
- **AchievementSystem**: registra conquistas de boas-vindas e formatura.
- **DailyRewards**: pode dar bônus extra para recrutas nos primeiros 3 dias.
- **TeamSystem**, **DuelSystem** e **BossRaid**: entram apenas no fim da jornada para apresentar conteúdo social sem assustar o jogador.

## Regras de design

- Cada capítulo deve levar de 3 a 7 minutos.
- Nenhum passo deve bloquear permanentemente o jogador se um sistema estiver indisponível.
- As recompensas devem ajudar o início, mas não quebrar a economia.
- O painel precisa abrir pelo menu unificado, respeitando a regra de GUI do projeto.
- O progresso deve ser salvo no DataStore para o jogador continuar depois.

## Métricas para validar sucesso

- Percentual de jogadores que completa o primeiro combate.
- Tempo médio até equipar a primeira passiva.
- Retenção após 10, 30 e 45 minutos.
- Retorno no dia seguinte após receber recompensas iniciais.
- Quantidade de jogadores que chega à primeira atividade social.

## MVP implementado

A primeira versão implementa os três capítulos abaixo em `RecruitJourneyServer` e `RecruitJourneyClient`:

1. escolher personagem inicial;
2. derrotar 3 NPCs fracos;
3. subir 1 nível e receber uma recompensa de formatura parcial.

Depois desta versão, adicionar passiva, missão real e atividade social como capítulos extras.
