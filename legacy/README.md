# Legacy — versões substituídas

⚠️ **Nada aqui deve ir para o Roblox Studio.**

Estes arquivos são versões antigas que já foram substituídas pelas de `src/`.
Estão guardados apenas como histórico de consulta.

O projeto proíbe dois scripts da mesma família rodando ao mesmo tempo — colocar
qualquer coisa desta pasta no Studio junto com a versão de `src/` causa conflito.

| Arquivo | Versão | Substituído por | Local ativo |
|---|:--:|---|---|
| `CharacterSystemClient_V6.client.lua` | V6 | V7 | `src/StarterPlayer/StarterPlayerScripts/CharacterSystemClient.client.lua` |
| `DailyRewardsServer_V4.server.lua` | V4 | V5 | `src/ServerScriptService/DailyRewardsServer.server.lua` |
| `DataManager_V6.server.lua` | V6 | V8 | `src/ServerScriptService/DataManager.server.lua` |
| `HealthDisplay_V3.client.lua` | V3 | V4 | `src/StarterPlayer/StarterPlayerScripts/HealthDisplay.client.lua` |

## O que mudou em cada salto

- **CharacterSystemClient V6 → V7** — passa a exibir os atributos do personagem.
- **DailyRewardsServer V4 → V5** — revisão do fluxo de recompensa.
- **DataManager V6 → V8** — V7 não veio no pacote; a V8 amplia os limites de passiva.
  Note que vários cabeçalhos ainda dizem "DEPENDE DE: DataManager V7", o que é
  esperado: a V8 é compatível com o que a V7 expunha.
- **HealthDisplay V3 → V4** — acrescenta a barra de energia ao lado da barra de vida.

## Duplicata descartada

O pacote original também trazia `DailyRewardsClient_V1 (2).lua`, cópia **byte a byte
idêntica** de `DailyRewardsClient_V1.lua`. Como não havia diferença nenhuma, só a
versão canônica foi mantida, em
`src/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua`.
