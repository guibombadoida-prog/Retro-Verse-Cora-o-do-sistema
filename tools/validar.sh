#!/usr/bin/env bash
#
# validar.sh — confere as regras que este repositório precisa manter
#
# Checagens:
#   1. duplicata de família em src/ (dois scripts do mesmo sistema ativos)
#   2. barreiras `repeat task.wait() until _G.X` com dono presente
#   3. APIs _G consumidas sem ninguém definir
#   4. central/ vazia (senão, promoção pendente)
#   5. regras de código do projeto: wait()/spawn()/:Destroy()
#   6. nome do arquivo batendo com o `-- Nome:` do cabeçalho
#   7. sintaxe Lua de todos os scripts, incluindo boss-place/ (se houver luac)
#
# Uso: tools/validar.sh
# Sai com 1 se achar erro; avisos não derrubam o código de saída.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$RAIZ/src"
CENTRAL="$RAIZ/central"
# Place SEPARADA do chefão: mesma convenção interna, outro DataModel.
# Entra na checagem de sintaxe, mas NÃO na de duplicata de família — um
# script pode legitimamente existir nas duas places.
BOSS="$RAIZ/boss-place"

ERROS=0
AVISOS=0

ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
falha() {
	printf '  \033[31m✗\033[0m %s\n' "$*"
	ERROS=$((ERROS + 1))
}
aviso() {
	printf '  \033[33m!\033[0m %s\n' "$*"
	AVISOS=$((AVISOS + 1))
}
titulo() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# APIs que o projeto sabe que não têm dono e que são chamadas dentro de
# `if` — a ausência desliga o recurso, não trava sistema nenhum.
OPCIONAIS="PassiveVFX SetCoinMultiplier"

# Arquivos com uso de :Destroy() já existente e ainda NÃO revisado.
# A regra do projeto é "nunca :Destroy() SEM AUTORIZAÇÃO", então a
# exceção mora aqui, à vista, em vez de virar erro permanente que faz
# todo mundo ignorar o validador. Sai da lista quando for decidido se
# vira `.Parent = nil` ou se fica como está de propósito.
EXCECOES_DESTROY="AntiLag.server.lua"

# Só o código, sem comentário de linha e sem bloco --[[ ]].
# Evita acusar violação em cabeçalho que apenas MENCIONA a regra.
#
# Limitação conhecida e aceita: um "--" dentro de string literal também
# é cortado. Isso só pode gerar falso NEGATIVO (deixar de acusar algo
# escondido numa string), nunca falso positivo.
somente_codigo() {
	awk '
	BEGIN { bloco = 0 }
	{
		linha = $0
		if (bloco) {
			if (linha ~ /\]\]/) { bloco = 0; sub(/.*\]\]/, "", linha) } else { next }
		}
		if (linha ~ /--\[\[/) {
			if (linha ~ /\]\]/) { gsub(/--\[\[.*\]\]/, "", linha) }
			else { sub(/--\[\[.*/, "", linha); bloco = 1 }
		}
		sub(/--.*/, "", linha)
		if (linha ~ /[^ \t]/) print FILENAME ":" FNR ":" linha
	}' "$@"
}

sufixo_de() {
	case "$1" in
	*.server.lua) echo ".server.lua" ;;
	*.client.lua) echo ".client.lua" ;;
	*.lua) echo ".lua" ;;
	*) echo "" ;;
	esac
}

familia_de() {
	local arquivo suf
	arquivo="$(basename "$1")"
	suf="$(sufixo_de "$arquivo")"
	echo "${arquivo%$suf}" | sed -E 's/_[Vv][0-9]+(\.[0-9]+)?$//'
}

mapfile -t ATIVOS < <(find "$SRC" -type f -name "*.lua" | sort)

printf '\033[1mRetroVerse — validação do repositório\033[0m\n'

# ---------------------------------------------------------------
titulo "1. Duplicata de família em src/"
# ---------------------------------------------------------------
# A regra do projeto: "nunca dois scripts da mesma família rodando ao
# mesmo tempo". Aqui isso vira uma checagem em vez de disciplina.

declare -A vistos=()
dup=0
for f in "${ATIVOS[@]}"; do
	chave="$(familia_de "$f")$(sufixo_de "$f")"
	if [[ -n "${vistos[$chave]:-}" ]]; then
		falha "família duplicada: ${vistos[$chave]#$RAIZ/} e ${f#$RAIZ/}"
		dup=$((dup + 1))
	else
		vistos[$chave]="$f"
	fi
done
((dup == 0)) && ok "${#ATIVOS[@]} scripts ativos, 0 duplicatas de família"

# ---------------------------------------------------------------
titulo "2. Barreiras de espera (repeat ... until _G.X)"
# ---------------------------------------------------------------
# Se a dependência não existir, o repeat espera para sempre SEM erro no
# Output. É a falha mais difícil de diagnosticar no projeto.

mapfile -t DEFINIDAS < <(grep -rhoE '_G\.[A-Za-z_][A-Za-z0-9_]* *=[^=]' "$SRC" |
	sed -E 's/_G\.//; s/ *=.*//' | sort -u)

esta_definida() {
	local nome="$1"
	for d in "${DEFINIDAS[@]}"; do [[ "$d" == "$nome" ]] && return 0; done
	return 1
}

barreiras=0
barreiras_ok=0
while IFS= read -r linha; do
	arquivo="${linha%%:*}"
	resto="${linha#*:}"
	numero="${resto%%:*}"
	corpo="${resto#*:}"
	barreiras=$((barreiras + 1))

	faltando=""
	for api in $(grep -oE '_G\.[A-Za-z_][A-Za-z0-9_]*' <<<"$corpo" | sed 's/_G\.//' | sort -u); do
		esta_definida "$api" || faltando="$faltando $api"
	done

	if [[ -n "$faltando" ]]; then
		falha "${arquivo#$RAIZ/}:$numero espera por$faltando — nenhum script define"
	else
		barreiras_ok=$((barreiras_ok + 1))
	fi
done < <(grep -rn --include=*.lua -E '^[[:space:]]*until[[:space:]]+_G\.' "$SRC")

((barreiras_ok == barreiras)) && ok "$barreiras barreiras _G satisfeitas"

# ---------------------------------------------------------------
titulo "3. APIs _G consumidas sem dono"
# ---------------------------------------------------------------

mapfile -t CONSUMIDAS < <(grep -rhoE '_G\.[A-Za-z_][A-Za-z0-9_]*' "$SRC" | sed 's/_G\.//' | sort -u)

orfas=()
for api in "${CONSUMIDAS[@]}"; do
	esta_definida "$api" && continue
	conhecida=0
	for opt in $OPCIONAIS; do [[ "$api" == "$opt" ]] && conhecida=1; done
	if ((conhecida)); then
		aviso "_G.$api sem dono — opcional, protegida por if (só desliga o recurso)"
	else
		orfas+=("$api")
	fi
done

if ((${#orfas[@]} > 0)); then
	for api in "${orfas[@]}"; do
		falha "_G.$api é consumida mas nenhum script define"
	done
else
	ok "nenhuma dependência _G inesperada sem dono"
fi

# ---------------------------------------------------------------
titulo "4. Área de trânsito (central/)"
# ---------------------------------------------------------------

mapfile -t pendentes < <(find "$CENTRAL" -maxdepth 1 -type f -name "*.lua" 2>/dev/null | sort)
if ((${#pendentes[@]} == 0)); then
	ok "central/ vazia — repositório e Studio em sincronia"
else
	for p in "${pendentes[@]}"; do
		base_p="$(basename "$p")"
		fam_p="$(familia_de "$p")"
		# Qual versão está no ar agora, para o aviso dizer o que substitui
		no_ar=""
		for a in "${ATIVOS[@]}"; do
			if [[ "$(familia_de "$a")" == "$fam_p" ]]; then
				no_ar=" (substitui $(head -12 "$a" | grep -oiE '\bV[0-9]+' | head -1) que está no ar)"
				break
			fi
		done
		aviso "AGUARDA INSTALAÇÃO NO STUDIO: $base_p$no_ar"
		printf '      após colar no Studio, rode: tools/promover.sh %s\n' "$base_p"
	done
fi

# ---------------------------------------------------------------
titulo "5. Regras de código do projeto"
# ---------------------------------------------------------------

codigo="$(somente_codigo "${ATIVOS[@]}")"

conta_e_reporta() {
	local rotulo="$1" padrao="$2" excluir="$3" excecoes="${4:-}"
	local achados
	if [[ -n "$excluir" ]]; then
		achados="$(grep -E "$padrao" <<<"$codigo" | grep -vE "$excluir" || true)"
	else
		achados="$(grep -E "$padrao" <<<"$codigo" || true)"
	fi

	local reais=() isentos=()
	if [[ -n "$achados" ]]; then
		while IFS= read -r l; do
			local isento=0
			for ex in $excecoes; do
				[[ "$l" == *"$ex"* ]] && isento=1
			done
			if ((isento)); then isentos+=("$l"); else reais+=("$l"); fi
		done <<<"$achados"
	fi

	if ((${#reais[@]} == 0)); then
		ok "$rotulo"
	else
		for l in "${reais[@]}"; do falha "$rotulo — ${l#$RAIZ/}"; done
	fi
	for l in "${isentos[@]}"; do
		aviso "exceção registrada — ${l#$RAIZ/}  (ver EXCECOES_DESTROY no topo deste script)"
	done
}

# A alternância com [[:space:]]* é necessária: as linhas vêm prefixadas
# com "arquivo:NN:", então uma chamada no INÍCIO da linha não tem nenhum
# caractere antes dela para o [^.a-zA-Z_0-9] casar — e era esse o caso
# mais comum de todos.
conta_e_reporta "sem wait() solto (use task.wait)" \
	':[0-9]+:([[:space:]]*|.*[^.a-zA-Z_0-9])wait\(' 'task\.wait|:Wait\(|WaitForChild'
conta_e_reporta "sem spawn() solto (use task.spawn)" \
	':[0-9]+:([[:space:]]*|.*[^.a-zA-Z_0-9])spawn\(' 'task\.spawn'
# O ']' vem primeiro dentro do []: em ERE, barra invertida não escapa
# dentro de bracket expression, então "[a-zA-Z_)\]]" fecharia o bracket
# no '\]' e passaria a exigir um ']' literal antes de :Destroy().
conta_e_reporta "sem :Destroy() (use .Parent = nil)" \
	':[0-9]+:.*[]a-zA-Z_)]:Destroy\(\)' '' "$EXCECOES_DESTROY"

# ---------------------------------------------------------------
titulo "6. Nome do arquivo x nome no Studio"
# ---------------------------------------------------------------
# O caminho do arquivo é a instrução de instalação. Se o basename não
# bate com o `-- Nome:` do cabeçalho, alguém vai colar no lugar errado.

divergentes=0
sem_nome=0
for f in "${ATIVOS[@]}"; do
	declarado="$(head -20 "$f" |
		grep -m1 -iE '^--[[:space:]]*Nome( do objeto no Studio)?:' |
		sed -E 's/.*:[[:space:]]*"?([^"]+)"?.*/\1/; s/[[:space:]]+$//' || true)"
	# tira comentário de parênteses tipo: Nome: "X" (EXATAMENTE ISSO)
	declarado="$(sed -E 's/[[:space:]]*\(.*$//' <<<"$declarado")"
	if [[ -z "$declarado" ]]; then
		sem_nome=$((sem_nome + 1))
		continue
	fi
	arquivo="$(basename "$f")"
	base="${arquivo%$(sufixo_de "$arquivo")}"
	if [[ "$base" != "$declarado" ]]; then
		falha "${f#$RAIZ/}: cabeçalho diz Nome \"$declarado\", arquivo diz \"$base\""
		divergentes=$((divergentes + 1))
	fi
done
((divergentes == 0)) && ok "$((${#ATIVOS[@]} - sem_nome)) nomes conferem com o cabeçalho"
((sem_nome > 0)) && aviso "$sem_nome script(s) sem '-- Nome:' no cabeçalho — nome no Studio não verificável"

# ---------------------------------------------------------------
titulo "7. Sintaxe"
# ---------------------------------------------------------------
# O Roblox usa Luau, e não existe luau aqui — mas o luac do Lua 5.4
# pega erro de estrutura (bloco sem end, parêntese aberto) desde que as
# construções que só o Luau tem sejam traduzidas antes. A tradução
# preserva a estrutura de blocos, que é justamente o que importa:
#   x += e   ->  x = x + e
#   continue ->  do end   (statement neutro, mantém o bloco)
# Isso pode deixar passar um erro de TIPO/semântica, nunca um erro de
# estrutura — e é erro de estrutura que quebra o script no Studio.

LUAC="$(command -v luac5.4 || command -v luac5.3 || command -v luac || true)"

if [[ -z "$LUAC" ]]; then
	aviso "luac não instalado — sintaxe não verificada (apt-get install lua5.4)"
else
	tmpdir="$(mktemp -d)"
	trap 'rm -rf "$tmpdir"' EXIT
	sint_ok=0
	# central/ entra aqui de propósito: um script entregue com erro de
	# sintaxe tem que ser pego ANTES de ser colado no Studio, não depois.
	SINTAXE_ALVOS=("${ATIVOS[@]}")
	for p in "${pendentes[@]}"; do
		SINTAXE_ALVOS+=("$p")
	done
	# boss-place/ também: script da place do chefe quebra o jogo do mesmo
	# jeito que script da principal.
	while IFS= read -r bp; do
		[[ -n "$bp" ]] && SINTAXE_ALVOS+=("$bp")
	done < <(find "$BOSS" -type f -name "*.lua" 2>/dev/null | sort)
	for f in "${SINTAXE_ALVOS[@]}"; do
		sed -E \
			-e 's/^([[:space:]]*)([A-Za-z_][A-Za-z0-9_.]*(\[[^]]*\])?)[[:space:]]*\.\.=[[:space:]]*/\1\2 = \2 .. /' \
			-e 's/^([[:space:]]*)([A-Za-z_][A-Za-z0-9_.]*(\[[^]]*\])?)[[:space:]]*([+*\/%^-])=[[:space:]]*/\1\2 = \2 \4 /' \
			-e 's/^([[:space:]]*)continue([[:space:]]*)$/\1do end\2/' \
			"$f" >"$tmpdir/x.lua"
		if "$LUAC" -p "$tmpdir/x.lua" 2>"$tmpdir/err"; then
			sint_ok=$((sint_ok + 1))
		else
			falha "sintaxe — ${f#$RAIZ/}: $(sed -E "s|.*x\.lua:([0-9]+): |linha \1: |" "$tmpdir/err" | head -1)"
		fi
	done
	((sint_ok == ${#SINTAXE_ALVOS[@]})) && ok "$sint_ok scripts sem erro de sintaxe (src/ + central/ + boss-place/)"
fi

# ---------------------------------------------------------------
titulo "Resultado"
# ---------------------------------------------------------------

if ((ERROS == 0)); then
	printf '  \033[32m✓ sem erros\033[0m'
	((AVISOS > 0)) && printf ', %d aviso(s)' "$AVISOS"
	printf '\n\n'
	exit 0
else
	printf '  \033[31m✗ %d erro(s)\033[0m' "$ERROS"
	((AVISOS > 0)) && printf ', %d aviso(s)' "$AVISOS"
	printf '\n\n'
	exit 1
fi
