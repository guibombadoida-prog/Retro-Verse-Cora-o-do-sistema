# Auditoria — modelo `Angel` (boss_model.rbxmx)

Modelo de referência baixado (o `bOSS FIGHT RETRO` citado nas Diretrizes).
**54 scripts**, 36 Parts, 4 Humanoids, 16 Sounds, 13 Animations.

**Veredito curto:** os *assets* prestam e valem muito. Os *scripts* não podem ir
para o jogo como estão — um deles quebra o combate inteiro.

---

## 1. Segurança — está limpo ✅

Free model baixado merece checagem de backdoor antes de qualquer coisa. Varri os
54 scripts:

| Vetor | Resultado |
|---|---|
| `require(assetId)` — carregar código remoto | **nenhum** |
| `loadstring` / `getfenv` / `setfenv` | **nenhum** |
| `HttpService` / URL externa | **nenhum** — todas as URLs são `roblox.com/asset/?id=`, que são referências de asset (som, malha, animação) |

### A pegadinha do README

O script `README` esconde código atrás de uma parede de ~2000 tabulações:

```lua
--[[<parede de tabs>--]]script:Destroy()--[[<parede de tabs> I dare you to press down ;)
```

O comentário **fecha** no meio (`--]]`), `script:Destroy()` executa, e outro
comentário abre. É um README que se autodestrói ao rodar, com uma provocação
escondida — "eu te desafio a apertar seta pra baixo".

Aqui ele só se apaga. Mas **é exatamente a técnica de backdoor de free model**:
código executável escondido onde o olho lê "comentário". Vale reconhecer o padrão.

➡️ **Apague o README.** Ele não faz nada útil e a instrução dele conflita com o
nosso sistema (ver seção 3).

---

## 2. O defeito grave — `KillScript` é uma aura de morte instantânea

```lua
while wait() do
    a = findNearestTorso(script.Parent.HumanoidRootPart.Position)
    if a ~= nil then
        if (script.Parent.HumanoidRootPart.Position - a.Position).magnitude < 10 then
            a.Parent.Humanoid.Health = 0    -- ⛔
            a:BreakJoints()
```

Quatro problemas, cada um sozinho já bastaria para não instalar:

**Mata zerando `Health`.** As Diretrizes proíbem isso em letra maiúscula: *"Dano
aplicado via `Humanoid:TakeDamage(valor)` — **NUNCA** zerar `Health` diretamente
como atalho para matar"*. Zerar `Health` pula o `_G.CanDamagePlayer`, o
`Boss_NoPvpProtection`, o `StatService`, as passivas de Negação e Reverso, e o
`DamageAttribution`. O sistema de combate inteiro é contornado.

**É morte instantânea, não dano.** Chegou a 10 studs, morreu. Sem dano, sem
cooldown, sem telegraph. A regra de AOE das Diretrizes pede aviso visual/sonoro
antes do dano cair, para dar chance de esquiva.

**A condição de alvo está quebrada.** Esta linha:

```lua
if (temp2.className == "Model") and (temp2 ~= script.Parent) and (temp2:FindFirstChild("") ~= nil)
   or (temp2:FindFirstChild("")==nil) and (temp2:FindFirstChild("ForceField") == nil) then
```

`FindFirstChild("")` sempre devolve `nil`, então o primeiro ramo do `or` é sempre
**falso**. Sobra o segundo, que reduz tudo a `FindFirstChild("ForceField") == nil`
— e no caminho **perde** as checagens de `className == "Model"` e
`temp2 ~= script.Parent`. Resultado: o chefe pode matar a si mesmo e a outros
NPCs, e nunca checa se o alvo é jogador.

**Varre a Workspace inteira todo frame.** `while wait() do` + `Workspace:children()`
a cada iteração. Com um mapa grande isso é custo puro, o tempo todo.

---

## 3. `DataStore` — conflita com o nosso fluxo de recompensa

```lua
store = game:GetService("DataStoreService"):GetDataStore("PeopleWithOpCoil")
...
d.Parent = plr:WaitForChild("StarterGear")   -- Gravity Coil permanente
```

O prêmio do modelo é um **Gravity Coil** salvo num DataStore próprio
(`PeopleWithOpCoil`), entregue direto no `StarterGear`.

Isso colide com duas regras nossas:

- As Diretrizes mandam a place do chefe usar **os mesmos nomes de DataStore** da
  principal — *"Nunca duplicar com nomes de DataStore diferentes"*. Este cria um
  dado paralelo que nenhum outro sistema enxerga.
- A recompensa do chefe é responsabilidade do `Boss_ExitTeleport` +
  `BossConfigServer`, na ordem obrigatória entrega → confirma → teleporta.

➡️ **Não instale o `DataStore` nem o `LoadScript`.** A recompensa é configurada
pelo `BossConfigServer` (personagem-prêmio e/ou badge).

---

## 4. Regras de código do projeto — violação em massa

| Regra | Ocorrências no modelo |
|---|---|
| `wait()` em vez de `task.wait()` | **93**, em 30 arquivos |
| `:Destroy()` / `spawn()` / `Health = 0` | **50**, em 26 arquivos |

Nenhum script do modelo segue as convenções do projeto. O `validar.sh` reprovaria
todos.

---

## 5. Outros defeitos estruturais

**O `Model` do chefe está sem nome.** A hierarquia é `Angel > (Model sem nome)`.
As Diretrizes pedem `DisplayName`/`Name` preenchido — é o que aparece nas falas,
na barra de HP e no anúncio de spawn.

**`Pathfinding` não usa `PathfindingService`.** Apesar do nome, é `MoveTo` em
linha reta com `Ray.new(... * math.huge)` e o depreciado
`FindPartOnRayWithIgnoreList`. Varre a Workspace inteira todo frame e não ignora
quem está na zona segura.

**Três cópias do mesmo GUI de HP.** `RemoteEvent`, `RemoteEventAlt` e
`RemoteEventAlt2` carregam `BossHp` + `Module3D` idênticos (4776 bytes cada, byte
a byte). É o padrão de fases do modelo — mas triplicar o código significa que
corrigir um bug exige lembrar de corrigir nos três.

---

## 6. O que APROVEITAR

Os assets são a parte valiosa, e são muitos:

| O que | Por quê |
|---|---|
| **Model, Parts, SpecialMesh, Decal, Hats** | O visual do chefe pronto |
| **13 Animations + 4 KeyframeSequences** (`AnimSaves`) | Animações já feitas |
| **16 Sounds** | Falas, impacto, explosão, trilha |
| **`genBolt` / `genLazer` / `genSkyLauncher`** | Os geradores de projétil são a ideia certa (ModuleScript gerador + Script de disparo), e as Diretrizes mandam reaproveitá-los. Precisam de `task.wait()` e de mandar o dano pelo `TakeDamage` |
| **`BossHp` (GUI)** | A barra de vida é a exceção permitida pelas Diretrizes. O conceito serve; o código precisa de limpeza |
| **Estrutura de fases** (Models irmãos) | Padrão validado, é o que a diretriz documenta |

---

## 7. Plano de instalação

1. **Apague do modelo antes de subir:** `README`, `KillScript` (+ `Delete`),
   `DataStore` (+ `LoadScript`, + `Hyper Mega Ultra Fusion Coil`).
2. **Dê nome ao Model** do chefe e preencha `Humanoid.DisplayName`.
3. **Instale o `Boss_ModelController`** (novo, em `boss-place/`) dentro do Model
   do chefe. Ele substitui `KillScript`, `Pathfinding`, `AI` e `AInot` por um
   cérebro único que segue as regras do projeto e conversa com o
   `BossConfigServer` / `BossGate` / `BossExit`.
4. **Mantenha** `AnimateSauce`, `ChatScript`, `AttackScript` e os `gen*` — mas
   troque `wait()` por `task.wait()` e garanta que o dano sai por `TakeDamage`.
5. **Deixe uma cópia só** do `BossHp`, não três.
