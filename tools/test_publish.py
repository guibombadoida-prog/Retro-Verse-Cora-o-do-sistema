#!/usr/bin/env python3
"""Roda tasks/apply_code_payload.luau de verdade, num Roblox falso, em modo check.

Por que existe: a REMOÇÃO de instâncias é a única coisa que a publicação faz
que não tem desfazer do lado do jogo. As outras operações sobrescrevem
`Source`, e o histórico de versões do Creator Dashboard devolve. Um erro na
lista de remoção apaga script de uma place de produção.

O harness em tests/publish_removal_harness.luau carrega a TAREFA REAL — o
mesmo arquivo que a Open Cloud executa — com o mesmo cabeçalho que
tools/run_code_publish.py prepende, e confere as quatro saídas possíveis de um
caminho de remoção: existe, já não existe, classe diferente e nome duplicado.

O sandbox do `luau` não tem `io`, então o fonte é embutido aqui, mesmo padrão
de tools/test_tutorial.py.

Não fala com a Roblox e não altera place nenhuma.
Uso: python3 tools/test_publish.py --luau /caminho/para/luau
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


def literal(source):
    equals = "="
    while "]" + equals + "]" in source:
        equals += "="
    return "[" + equals + "[" + source + "]" + equals + "]"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]

    tarefa = root / "tasks/apply_code_payload.luau"
    harness = root / "tests/publish_removal_harness.luau"
    for caminho in (tarefa, harness):
        if not caminho.is_file():
            print(f"  x falta {caminho.relative_to(root)}")
            return 1

    corpo = literal(tarefa.read_text(encoding="utf-8"))
    teste = literal(harness.read_text(encoding="utf-8"))

    driver = f"local test = assert(loadstring({teste}))\n"
    driver += f"test({corpo})\n"

    with tempfile.TemporaryDirectory(prefix="retroverse-publish-test-") as temp:
        caminho = Path(temp) / "driver.luau"
        caminho.write_text(driver, encoding="utf-8")
        concluido = subprocess.run([args.luau, str(caminho)], cwd=root)
    return concluido.returncode


if __name__ == "__main__":
    sys.exit(main())
