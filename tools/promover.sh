#!/usr/bin/env bash
#
# promover.sh — CONFIRMA que uma versão de central/ já foi instalada
#                no Studio, movendo-a para a pasta ativa em src/
#
# ⚠️ RODE ISTO DEPOIS DE COLAR O SCRIPT NO STUDIO, não antes.
#
# A regra do repositório: src/ espelha o que está RODANDO no Studio.
# Enquanto um script está em central/, ele foi entregue mas ainda não
# subiu no jogo. Este comando é o "já instalei":
#   1. descobre a qual script a versão nova pertence
#   2. apaga a versão anterior de src/ (o Git guarda o histórico)
#   3. move a nova para o lugar exato do Studio
#
# Uso:
#   tools/promover.sh AwakeningSystemServer_V3.server.lua
#   tools/promover.sh central/DataManager_V9.server.lua
#   tools/promover.sh --todos          # confirma tudo que estiver em central/
#
# O destino não é adivinhado: vem do cabeçalho do próprio script
# (`-- Nome: "..."` e `-- Coloque em ...`), a mesma convenção que o
# projeto já usa.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CENTRAL="$RAIZ/central"
SRC="$RAIZ/src"

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
vermelho() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
amarelo() { printf '\033[33m%s\033[0m\n' "$*"; }

erro() {
	vermelho "✗ $*"
	exit 1
}

# ---------------------------------------------------------------
# Leitura do cabeçalho
# ---------------------------------------------------------------

# Versão declarada nas primeiras linhas (V1, V8, V4.1...)
versao_de() {
	head -12 "$1" | grep -oiE '\bV[0-9]+(\.[0-9]+)?\b' | head -1 || true
}

# Nome do objeto no Studio, quando o cabeçalho declara
nome_studio_de() {
	head -20 "$1" \
		| grep -m1 -iE '^--[[:space:]]*Nome( do objeto no Studio)?:' \
		| sed -E 's/.*:[[:space:]]*"?([^"]+)"?.*/\1/' \
		| sed -E 's/[[:space:]]+$//' || true
}

# Sufixo de classe: .server.lua | .client.lua | .lua
sufixo_de() {
	case "$1" in
	*.server.lua) echo ".server.lua" ;;
	*.client.lua) echo ".client.lua" ;;
	*.lua) echo ".lua" ;;
	*) echo "" ;;
	esac
}

# Base do nome, sem o sufixo de classe
base_de() {
	local arquivo suf
	arquivo="$(basename "$1")"
	suf="$(sufixo_de "$arquivo")"
	echo "${arquivo%$suf}"
}

# Família = base sem o _V<n> final. É o que agrupa DataManager_V6,
# _V7 e _V8 como sendo o mesmo script.
familia_de() {
	base_de "$1" | sed -E 's/_[Vv][0-9]+(\.[0-9]+)?$//'
}

# Pasta ativa a partir do "Coloque em ..." do cabeçalho.
# Usado só quando o script é novo e ainda não tem versão ativa.
pasta_pelo_cabecalho() {
	local cab
	cab="$(head -25 "$1" | tr -d '\r')"

	if grep -qiE 'StarterCharacterScripts' <<<"$cab"; then
		echo "$SRC/StarterPlayer/StarterCharacterScripts"
	elif grep -qiE 'StarterPlayerScripts' <<<"$cab"; then
		echo "$SRC/StarterPlayer/StarterPlayerScripts"
	elif grep -qiE 'ReplicatedFirst' <<<"$cab"; then
		echo "$SRC/ReplicatedFirst"
	elif grep -qiE 'ServerScriptService[[:space:]]*>[[:space:]]*RetroVerse' <<<"$cab"; then
		echo "$SRC/ServerScriptService/RetroVerse"
	elif grep -qiE 'ServerScriptService' <<<"$cab"; then
		echo "$SRC/ServerScriptService"
	else
		echo ""
	fi
}

# ---------------------------------------------------------------
# Promoção de um arquivo
# ---------------------------------------------------------------

promover() {
	local novo="$1"
	[[ -f "$novo" ]] || erro "não encontrei o arquivo: $novo"

	local suf familia versao_nova
	suf="$(sufixo_de "$novo")"
	[[ -n "$suf" ]] || erro "$(basename "$novo"): extensão precisa ser .server.lua, .client.lua ou .lua"

	familia="$(familia_de "$novo")"
	versao_nova="$(versao_de "$novo")"
	[[ -n "$versao_nova" ]] || versao_nova="?"

	# Procura a versão ativa da mesma família em src/
	local ativos=()
	while IFS= read -r encontrado; do
		[[ -n "$encontrado" ]] && ativos+=("$encontrado")
	done < <(find "$SRC" -type f -name "*.lua" -print | while read -r f; do
		if [[ "$(familia_de "$f")" == "$familia" && "$(sufixo_de "$f")" == "$suf" ]]; then
			echo "$f"
		fi
	done)

	if ((${#ativos[@]} > 1)); then
		vermelho "✗ $familia tem ${#ativos[@]} versões ativas em src/ — resolva antes de promover:"
		printf '    %s\n' "${ativos[@]#$RAIZ/}" >&2
		exit 1
	fi

	# ---- destino ----
	local pasta_destino nome_destino
	if ((${#ativos[@]} == 1)); then
		pasta_destino="$(dirname "${ativos[0]}")"
	else
		pasta_destino="$(pasta_pelo_cabecalho "$novo")"
		[[ -n "$pasta_destino" ]] || erro "$(basename "$novo") é script novo e o cabeçalho não diz onde colocar. Adicione a linha '-- Coloque em ...'."
		amarelo "  ⚑ script novo (nenhuma versão ativa) — destino pelo cabeçalho"
	fi

	# O nome do arquivo segue o nome do objeto no Studio. Cinco scripts
	# do projeto têm o _V<n> dentro do próprio nome do objeto, e é o
	# cabeçalho que manda — por isso ele tem prioridade sobre a família.
	nome_destino="$(nome_studio_de "$novo")"
	[[ -n "$nome_destino" ]] || nome_destino="$familia"

	local destino="$pasta_destino/${nome_destino}${suf}"

	# ---- remove a versão que estava ativa ----
	if ((${#ativos[@]} == 1)); then
		local antigo versao_antiga
		antigo="${ativos[0]}"
		versao_antiga="$(versao_de "$antigo")"
		[[ -n "$versao_antiga" ]] || versao_antiga="?"

		if [[ "$antigo" == "$novo" ]]; then
			erro "$(basename "$novo") já é o arquivo ativo"
		fi

		# Só apaga o que o Git já tem guardado. Sem isso, promover por
		# cima de um arquivo nunca comitado perderia o conteúdo de vez.
		if ! git -C "$RAIZ" ls-files --error-unmatch "$antigo" >/dev/null 2>&1; then
			erro "$(basename "$antigo") não está comitado — comite antes de promover, senão a versão antiga é perdida de verdade"
		fi

		git -C "$RAIZ" rm -q -f "$antigo"
		verde "  ✓ saiu do ar  ${antigo#$RAIZ/}  ($versao_antiga)  — recuperável no histórico do Git"
	fi

	# ---- move a nova para o lugar ----
	mkdir -p "$pasta_destino"
	if git -C "$RAIZ" ls-files --error-unmatch "$novo" >/dev/null 2>&1; then
		git -C "$RAIZ" mv -f "$novo" "$destino"
	else
		mv -f "$novo" "$destino"
		git -C "$RAIZ" add "$destino"
	fi
	verde "  ✓ no ar      ${novo#$RAIZ/} → ${destino#$RAIZ/}  ($versao_nova)"
}

# ---------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------

git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || erro "isto precisa rodar dentro do repositório Git"

if (($# == 0)); then
	sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 1
fi

alvos=()
if [[ "$1" == "--todos" ]]; then
	while IFS= read -r f; do
		alvos+=("$f")
	done < <(find "$CENTRAL" -maxdepth 1 -type f -name "*.lua" | sort)
	((${#alvos[@]} > 0)) || {
		amarelo "central/ está vazia — nada pendente de instalação no Studio"
		exit 0
	}
else
	for arg in "$@"; do
		if [[ -f "$arg" ]]; then
			alvos+=("$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")")
		elif [[ -f "$CENTRAL/$arg" ]]; then
			alvos+=("$CENTRAL/$arg")
		else
			erro "não encontrei '$arg' nem em central/"
		fi
	done
fi

for alvo in "${alvos[@]}"; do
	echo "→ $(basename "$alvo")"
	promover "$alvo"
done

echo
amarelo "Rode 'tools/validar.sh' antes de comitar."
amarelo "Lembre: isto só vale se o script JÁ estiver colado no Studio."
