#!/usr/bin/env python3
"""Confere a instalação do Adonis: estrutura da árvore e configurações de segurança.

Duas metades, por motivos diferentes:

1. Invariantes de ESTRUTURA (aqui, em Python). O carregador do Adonis navega
   por caminho fixo e indexa algumas pastas DIRETO, sem FindFirstChild —
   `configFolder.Plugins` e `configFolder.Themes`. Pasta que falta é erro na
   hora de subir o servidor. E a publicação "somente código" só cria pasta que
   está no caminho de algum script (resolveParent, em
   tasks/apply_code_payload.luau), então pasta sem módulo dentro NÃO CHEGA ao
   jogo. Essas duas regras juntas são fáceis de violar limpando "arquivo
   inútil", e o efeito só aparece no jogo.

2. Configurações de SEGURANÇA (em tests/adonis_settings_harness.luau, que roda
   os módulos de verdade no Luau).

Não fala com a Roblox e não altera place nenhuma.
Uso: python3 tools/test_adonis.py --luau /caminho/para/luau
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ADONIS = Path("src/ServerScriptService/Adonis_Loader")

# Caminho -> por que o carregador precisa dele.
# As linhas citadas são de Loader/Loader.server.lua.
OBRIGATORIOS = {
    "Loader/Loader.server.lua": "o Script que sobe o Adonis; o resto é achado por script.Parent.Parent",
    "Config/Settings/General.lua": "settingsFolder:GetChildren() — sem módulo, Adonis usa defaults",
    "Config/Settings/Ranks.lua": "define quem é admin",
    "Config/Settings/AntiExploit.lua": "sem ele, as detecções voltam ao default do autor",
    "Config/Settings/Trello.lua": "onde as credenciais do Trello NÃO devem estar",
    "Config/Settings/_GAPI.lua": "controla se o Adonis publica _G.Adonis",
    "Config/Settings/Donor.lua": "capas e comandos de doador",
    "Config/InGameSettingsEditorSettings/Descriptions.lua": "require direto em inGameSettingsEditorSettingsFolder.Descriptions",
    "Config/InGameSettingsEditorSettings/Order.lua": "require direto em inGameSettingsEditorSettingsFolder.Order",
}

# Pastas que o carregador indexa SEM FindFirstChild: ausência = erro imediato.
# Precisam de >= 1 módulo para a publicação criá-las.
PASTAS_INDEXADAS_DIRETO = {
    "Config": "local configFolder = model.Config",
    "Config/Plugins": "local pluginsFolder = configFolder.Plugins",
    "Config/Themes": "local themesFolder = configFolder.Themes",
    "Loader": "local loaderFolder = model.Loader",
}


def literal(source):
    equals = "="
    while "]" + equals + "]" in source:
        equals += "="
    return "[" + equals + "[" + source + "]" + equals + "]"


def tabela_de(arquivos, raiz):
    """Monta `{{name = "X", source = [[...]]}}` para o harness em Luau."""
    partes = []
    for caminho in sorted(arquivos):
        nome = caminho.stem
        fonte = literal(caminho.read_text(encoding="utf-8"))
        partes.append(f'{{name = "{nome}", source = {fonte}}}')
    return "{" + ",\n".join(partes) + "}"


def conferir_estrutura(root):
    """Devolve a lista de problemas de estrutura encontrados."""
    base = root / ADONIS
    falhas = []

    if not base.is_dir():
        return [f"{ADONIS} não existe"]

    for relativo, motivo in sorted(OBRIGATORIOS.items()):
        if not (base / relativo).is_file():
            falhas.append(f"falta {ADONIS / relativo} — {motivo}")

    for relativo, linha in sorted(PASTAS_INDEXADAS_DIRETO.items()):
        pasta = base / relativo
        if not pasta.is_dir():
            falhas.append(f"falta a pasta {ADONIS / relativo} — o carregador faz `{linha}`")
            continue
        # Só script cria pasta na publicação. Basta UM em qualquer nível abaixo.
        if not any(pasta.rglob("*.lua")):
            falhas.append(
                f"{ADONIS / relativo} não tem nenhum .lua dentro — a publicação só cria pasta "
                f"no caminho de um script, então esta pasta não chegaria ao jogo, e o "
                f"carregador faz `{linha}`"
            )

    # Settings TEM de ser uma pasta com módulos: o carregador testa
    # `settingsFolder:IsA("Folder")` e, se não for, lê tudo como "settings
    # legado" — silenciosamente errado.
    settings = base / "Config/Settings"
    if settings.is_dir():
        modulos = list(settings.glob("*.lua"))
        if not modulos:
            falhas.append(f"{ADONIS}/Config/Settings está vazia")
    else:
        falhas.append(f"{ADONIS}/Config/Settings precisa ser uma pasta")

    # O Loader tem de ser Script (.server.lua). Como ModuleScript ou
    # LocalScript ele nunca roda, e o jogo sobe sem admin nenhum, sem erro.
    loader = base / "Loader/Loader.server.lua"
    if loader.is_file():
        irmaos = [p.name for p in (base / "Loader").glob("*.lua")]
        if "Loader.client.lua" in irmaos or "Loader.lua" in irmaos:
            falhas.append("há outro Loader em Loader/ além do .server.lua — dois carregadores")

    # Nome de plugin fora do padrão é ignorado pelo Adonis com um warn fácil
    # de não ver no Output.
    plugins = base / "Config/Plugins"
    if plugins.is_dir():
        for plugin in sorted(plugins.glob("*.lua")):
            nome = plugin.stem.lower()
            if not (nome.startswith("client-") or nome.startswith("client:")
                    or nome.startswith("server-") or nome.startswith("server:")):
                falhas.append(
                    f"plugin {plugin.name}: nome precisa começar com Server- ou Client- "
                    f"(o carregador casa com `^client[%-:]` / `^server[%-:]`)"
                )

    return falhas


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]

    falhas = conferir_estrutura(root)
    if falhas:
        print(f"\n{len(falhas)} problema(s) de estrutura na instalação do Adonis:\n")
        for f in falhas:
            print(f"  x {f}")
        print()
        return 1
    print(
        f"Adonis: estrutura ok — {len(OBRIGATORIOS)} arquivos obrigatórios, "
        f"{len(PASTAS_INDEXADAS_DIRETO)} pastas indexadas direto"
    )

    base = root / ADONIS
    modulos = tabela_de((base / "Config/Settings").glob("*.lua"), base)
    plugins = tabela_de((base / "Config/Plugins").glob("*.lua"), base)
    harness = literal((root / "tests/adonis_settings_harness.luau").read_text(encoding="utf-8"))

    driver = f"local test = assert(loadstring({harness}))()\n"
    driver += f"test({modulos}, {plugins})\n"

    with tempfile.TemporaryDirectory(prefix="retroverse-adonis-test-") as temp:
        path = Path(temp) / "driver.luau"
        path.write_text(driver, encoding="utf-8")
        concluido = subprocess.run([args.luau, str(path)], cwd=root)
    return concluido.returncode


if __name__ == "__main__":
    sys.exit(main())
