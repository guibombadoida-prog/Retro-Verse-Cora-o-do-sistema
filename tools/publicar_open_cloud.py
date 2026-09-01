#!/usr/bin/env python3
"""
Publica os scripts do repositório numa place do Roblox SEM ABRIR O STUDIO.

POR QUE ESTE CAMINHO, E NÃO `rojo build` + publish
--------------------------------------------------
`rojo build` monta a place INTEIRA a partir dos arquivos. Este repositório
só tem scripts — StarterGui, Workspace, ReplicatedStorage, Lighting e
ServerStorage vivem apenas dentro da place. Publicar um build daqui
substituiria o jogo por um mundo vazio com scripts soltos.

Então em vez de reconstruir a place, este script MANDA UM RECADO para
dentro dela: uma tarefa Luau que percorre a árvore, escreve o `.Source` de
cada Script e salva. Tudo que não é script fica intocado.

COMO FUNCIONA
-------------
1. Lê src/ (ou a pasta que você passar) e monta {caminho -> código}.
2. Gera um script Luau que embute esse pacote em JSON.
3. POST na Luau Execution API, que roda o script dentro da place.
4. Faz polling até terminar e imprime os logs.

LIMITES DA API (conferidos na doc oficial em setembro/2026)
-----------------------------------------------------------
  • Script: no máximo 4 MB   -> os fontes deste repo somam ~1,3 MB
  • Execução: 5 minutos
  • Criar tarefa: 5 chamadas por minuto  -> por isso vai TUDO numa tarefa só
  • Escopos da chave: universe.place.luau-execution-session:write e :read

USO
---
  export ROBLOX_API_KEY=...
  export ROBLOX_UNIVERSE_ID=...
  export ROBLOX_PLACE_ID=...
  python3 tools/publicar_open_cloud.py            # confere e mostra o plano
  python3 tools/publicar_open_cloud.py --publicar # manda de verdade
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://apis.roblox.com/cloud/v2"

# Onde cada pasta do repositório mora dentro da place.
# A chave é o caminho no disco; o valor é o caminho de serviços no Studio.
MAPA = {
    "src/ServerScriptService": ["ServerScriptService"],
    "src/ServerScriptService/RetroVerse": ["ServerScriptService", "RetroVerse"],
    "src/StarterPlayer/StarterPlayerScripts": ["StarterPlayer", "StarterPlayerScripts"],
    "src/StarterPlayer/StarterCharacterScripts": ["StarterPlayer", "StarterCharacterScripts"],
    "src/ReplicatedFirst": ["ReplicatedFirst"],
}

CLASSE = {
    ".server.lua": "Script",
    ".client.lua": "LocalScript",
    ".lua": "ModuleScript",
}


def classe_de(nome):
    for sufixo, classe in CLASSE.items():
        if nome.endswith(sufixo):
            return classe, nome[: -len(sufixo)]
    return None, None


def coletar(raiz="."):
    """Monta a lista de scripts. Só pastas mapeadas — nada é adivinhado."""
    itens = []
    for pasta, destino in MAPA.items():
        caminho = os.path.join(raiz, pasta)
        if not os.path.isdir(caminho):
            continue

        for nome in sorted(os.listdir(caminho)):
            arquivo = os.path.join(caminho, nome)
            if not os.path.isfile(arquivo):
                continue

            classe, base = classe_de(nome)
            if not classe:
                continue

            with open(arquivo, encoding="utf8") as f:
                itens.append(
                    {
                        "caminho": destino,
                        "nome": base,
                        "classe": classe,
                        "codigo": f.read(),
                    }
                )
    return itens


def nivel_seguro(texto):
    """Acha um nível de colchete longo que não colida com o conteúdo."""
    nivel = 0
    while ("]" + "=" * nivel + "]") in texto:
        nivel += 1
    return "=" * nivel


# O script que roda DENTRO da place.
LUAU = """
-- Gerado por tools/publicar_open_cloud.py — não edite à mão.
local HttpService = game:GetService("HttpService")

local pacote = HttpService:JSONDecode([{eq}[{json}]{eq}])

local criados, atualizados, iguais = 0, 0, 0
local problemas = {{}}

-- Caminha até a pasta destino, criando as intermediárias que faltarem.
local function chegarEm(partes)
    local atual = game
    for i, nome in ipairs(partes) do
        local proximo
        if i == 1 then
            local ok, servico = pcall(function()
                return game:GetService(nome)
            end)
            proximo = ok and servico or nil
        else
            proximo = atual:FindFirstChild(nome)
            if not proximo then
                proximo = Instance.new("Folder")
                proximo.Name = nome
                proximo.Parent = atual
            end
        end
        if not proximo then
            return nil
        end
        atual = proximo
    end
    return atual
end

for _, item in ipairs(pacote) do
    local pai = chegarEm(item.caminho)

    if not pai then
        table.insert(problemas, "sem destino: " .. table.concat(item.caminho, "."))
    else
        local alvo = pai:FindFirstChild(item.nome)

        -- Nome existente mas de outra classe: trocar seria destrutivo.
        -- Prefiro acusar e deixar a decisão para uma pessoa.
        if alvo and not alvo:IsA(item.classe) then
            table.insert(
                problemas,
                string.format(
                    "%s existe como %s, esperado %s — NÃO alterado",
                    item.nome, alvo.ClassName, item.classe
                )
            )
        else
            if not alvo then
                alvo = Instance.new(item.classe)
                alvo.Name = item.nome
                alvo.Parent = pai
                criados = criados + 1
                alvo.Source = item.codigo
            elseif alvo.Source ~= item.codigo then
                alvo.Source = item.codigo
                atualizados = atualizados + 1
            else
                iguais = iguais + 1
            end
        end
    end
end

print(string.format(
    "[SYNC] criados=%d atualizados=%d sem-mudanca=%d problemas=%d",
    criados, atualizados, iguais, #problemas
))
for _, p in ipairs(problemas) do
    warn("[SYNC] " .. p)
end

-- Só salva se algo mudou de verdade: SavePlaceAsync cria uma versão nova
-- da place a cada chamada, e versão sem mudança é só lixo no histórico.
if criados + atualizados > 0 then
    -- ⚠️ CORRECAO: eu tinha escrito game:SavePlaceAsync(), que NAO EXISTE.
    -- SavePlaceAsync e do AssetService. Sem isto o script rodaria, trocaria
    -- os Source e falharia justamente ao persistir — o pior tipo de falha,
    -- porque tudo parece ter funcionado ate a ultima linha.
    local ok, err = pcall(function()
        game:GetService("AssetService"):SavePlaceAsync({ SaveWithoutPublish = false })
    end)
    if ok then
        print("[SYNC] place salva")
    else
        warn("[SYNC] FALHA ao salvar: " .. tostring(err))
        error("SavePlaceAsync falhou")
    end
else
    print("[SYNC] nada mudou — place nao foi salva")
end

return {{ criados = criados, atualizados = atualizados, problemas = problemas }}
"""


def montar_script(itens):
    payload = json.dumps(itens, ensure_ascii=False)
    return LUAU.format(eq=nivel_seguro(payload), json=payload)


class SemPermissaoDeLeitura(Exception):
    """A chave pode criar a tarefa mas não pode ler o resultado."""


def pedir(url, chave, metodo="GET", corpo=None):
    dados = json.dumps(corpo).encode() if corpo is not None else None
    req = urllib.request.Request(url, data=dados, method=metodo)
    req.add_header("x-api-key", chave)
    if dados:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode(errors="replace")

        # 401/403 numa LEITURA quase sempre é escopo :read faltando na
        # chave. Não é motivo para abortar: a tarefa já foi criada e vai
        # rodar do mesmo jeito — só perdemos o acompanhamento.
        if metodo == "GET" and e.code in (401, 403):
            raise SemPermissaoDeLeitura(detalhe)

        raise SystemExit(f"HTTP {e.code} em {metodo} {url}\n{detalhe}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--publicar", action="store_true", help="manda de verdade")
    ap.add_argument("--raiz", default=".", help="raiz do repositório")
    args = ap.parse_args()

    itens = coletar(args.raiz)
    if not itens:
        raise SystemExit("Nenhum script encontrado — confira o MAPA no topo.")

    script = montar_script(itens)
    tamanho = len(script.encode())

    print(f"Scripts encontrados : {len(itens)}")
    print(f"Tamanho da tarefa   : {tamanho / 1024:.0f} KB  (limite: 4096 KB)")

    if tamanho > 4 * 1024 * 1024:
        raise SystemExit(
            "Passou de 4 MB. Divida em lotes — mas lembre do limite de 5 "
            "criações de tarefa por minuto."
        )

    por_destino = {}
    for i in itens:
        por_destino[".".join(i["caminho"])] = por_destino.get(".".join(i["caminho"]), 0) + 1
    for destino, n in sorted(por_destino.items()):
        print(f"  {n:3d}  ->  {destino}")

    if not args.publicar:
        print("\nEnsaio apenas. Use --publicar para mandar de verdade.")
        return

    chave = os.environ.get("ROBLOX_API_KEY")
    universo = os.environ.get("ROBLOX_UNIVERSE_ID")
    place = os.environ.get("ROBLOX_PLACE_ID")
    if not (chave and universo and place):
        raise SystemExit(
            "Faltam variáveis: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID"
        )

    base = f"{API}/universes/{universo}/places/{place}"
    print("\nCriando a tarefa...")
    tarefa = pedir(
        f"{base}/luau-execution-session-tasks", chave, "POST", {"script": script}
    )

    caminho = tarefa["path"]
    print(f"Tarefa: {caminho}")

    # Polling. O teto de 5 min é da API; aqui damos folga e desistimos depois.
    limite = time.time() + 360
    estado = tarefa.get("state")

    try:
        while (
            estado in ("STATE_UNSPECIFIED", "QUEUED", "PROCESSING")
            and time.time() < limite
        ):
            time.sleep(3)
            tarefa = pedir(f"{API}/{caminho}", chave)
            estado = tarefa.get("state")
            print(f"  ... {estado}")

        print(f"\nEstado final: {estado}")

        logs = pedir(f"{API}/{caminho}/logs", chave)
        for entrada in logs.get("luauExecutionSessionTaskLogs", []):
            for linha in entrada.get("messages", []):
                print("  |", linha)

    except SemPermissaoDeLeitura:
        # A chave só tem o escopo de escrita. A tarefa FOI criada e vai
        # rodar normalmente — o que perdemos é só o acompanhamento.
        print()
        print("=" * 62)
        print("A tarefa foi criada, mas esta chave não pode LER o resultado.")
        print()
        print("Falta o escopo de leitura:")
        print("  universe.place.luau-execution-session:read")
        print()
        print("A publicação provavelmente funcionou — só não dá para")
        print("confirmar por aqui. Para checar, entre no jogo e veja se as")
        print("mudanças estão lá.")
        print()
        print("Para voltar a ter confirmação, edite a chave no Creator")
        print("Dashboard e marque também a operação de leitura.")
        print("=" * 62)
        return

    if estado != "COMPLETE":
        print(json.dumps(tarefa.get("error", {}), indent=2, ensure_ascii=False))
        raise SystemExit(1)

    print("\nPublicado.")


if __name__ == "__main__":
    main()
