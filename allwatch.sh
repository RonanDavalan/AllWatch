#!/usr/bin/env bash
# MIT License — Copyright (c) 2026 Ronan Davalan (texte complet : fichier LICENSE)
#
# allwatch.sh — supervise des cibles lancées au premier plan et les relance selon leur politique
#
# Pourquoi : juger la santé d'une cible par le seul noyau (/proc), un port TCP et son
#     code de sortie, sans agent ni protocole applicatif de son côté.
#
# Entrée / sortie : allwatch.sh [fichier.conf] (défaut allwatch.conf), Bash 5 au moins.
#     Options : --version (affiche la version) ; --diagnose [fichier.conf] (contrôle sans lancer) ;
#     --help (affiche ce résumé).
#     État dans ${ALLWATCH_RUNTIME:-/tmp/allwatch-runtime}, vidé à la sortie ; journal plat
#     dans ${XDG_STATE_HOME:-$HOME/.local/state}/allwatch/allwatch.log.
set -euo pipefail

# --- Bloc 1 : constantes et configuration ---
VERSION="0.1.0"
MODE="run"
case "${1:-}" in
  --version) printf 'allwatch %s\n' "$VERSION"; exit 0 ;;
  --help) printf 'Usage : allwatch [CONFIGURATION]\n        allwatch --version\n        allwatch --diagnose [CONFIGURATION]\n        allwatch --help\n\nAllWatch supervise des cibles au premier plan : noyau (/proc), port TCP et code de sortie.\nOptions : --version ; --diagnose [CONF] (lecture sans lancement) ; --help.\nVariables : ALLWATCH_RUNTIME (état) ; XDG_STATE_HOME (journal).\nConfiguration : ON_FREEZE=restart|alert (cible gelée : neutralisée et relancée, ou signalée sans signal). Voir allwatch(1).\n'
    exit 0 ;;
  --diagnose) MODE="diagnose"; shift ;;
esac
CONF="${1:-allwatch.conf}"
RT="${ALLWATCH_RUNTIME:-/tmp/allwatch-runtime}"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/allwatch/allwatch.log"
POLL_SECONDS=5 PROBE_TIMEOUT=3 MAX_RESTARTS=5 RESTART_WINDOW=60 ON_FREEZE=restart
declare -A PORT POL CMD FIN SUSPECT CHILD GEL
IDS=()

[ -r "$CONF" ] || { echo "allwatch: configuration illisible : $CONF" >&2; exit 1; }
while read -r id port pol cmd || [ -n "$id" ]; do
  case "$id" in
    '' | '#'*) continue ;;
    POLL_SECONDS=* | PROBE_TIMEOUT=* | MAX_RESTARTS=* | RESTART_WINDOW=* | ON_FREEZE=*) declare "$id"; continue ;;
  esac
  read -ra argv <<<"$cmd"
  IDS+=("$id"); PORT[$id]=$port; POL[$id]=$pol; CMD[$id]="${argv[*]}"
  FIN[$id]=0; SUSPECT[$id]=0; CHILD[$id]=0; GEL[$id]=0
done <"$CONF"
# Une faute de frappe ne doit jamais décider seule de tuer ou d'épargner une cible gelée.
case "$ON_FREEZE" in restart | alert) ;; *) echo "allwatch: ON_FREEZE vaut restart ou alert, pas '$ON_FREEZE'" >&2; exit 1 ;; esac
# Deux sondes en échec au moins avant de neutraliser : un ralentissement passager n'en coûte pas une.
GRACE=$((2 * POLL_SECONDS))

# Diagnostic statique : lit la configuration et les chemins, ne lance ni ne sonde aucune cible.
diagnostiquer() {
  local rc=0 id
  printf 'allwatch %s\n' "$VERSION"
  printf 'configuration: %s\n' "$CONF"
  printf 'runtime: %s\n' "$RT"
  printf 'journal: %s\n' "$LOG"
  printf 'on_freeze: %s\n' "$ON_FREEZE"
  printf 'targets: %d\n' "${#IDS[@]}"
  for id in "${IDS[@]}"; do
    printf '  %s port=%s policy=%s\n' "$id" "${PORT[$id]}" "${POL[$id]}"
  done
  if [ -e "$RT" ]; then
    if [ -d "$RT" ] && [ -O "$RT" ]; then
      printf 'runtime: owned by current user\n'
    else
      printf 'runtime: exists but is not a directory owned by the current user\n' >&2
      rc=1
    fi
  else
    printf 'runtime: absent (created at startup)\n'
  fi
  if [ -e "${LOG%/*}" ]; then
    if [ -d "${LOG%/*}" ] && [ -w "${LOG%/*}" ]; then
      printf 'log directory: writable\n'
    else
      printf 'log directory: exists but is not a writable directory\n' >&2
      rc=1
    fi
  else
    printf 'log directory: absent (created at startup)\n'
  fi
  return "$rc"
}

if [ "$MODE" = diagnose ]; then
  diagnostiquer
  exit $?
fi

# Un répertoire d'état qui n'est pas à nous laisserait un tiers dicter les PID que nous tuons.
# shellcheck disable=SC2174 # -m vise les deux dossiers nommés ; leurs parents gardent le masque par défaut.
mkdir -p -m 700 "$RT" "${LOG%/*}"
[ -O "$RT" ] || { echo "allwatch: $RT n'appartient pas à l'utilisateur" >&2; exit 1; }

# --- Bloc 2 : primitives d'inspection ---
journal() { printf '%s %s %s\n' "$(date -Iseconds)" "$1" "$2" >>"$LOG"; }

# /proc/<pid>/exe désigne l'interpréteur pour un script : seule la cmdline porte la cible.
# Un zombie a une cmdline vide, donc il n'existe plus.
existe() {
  local -a a
  mapfile -d '' -t a 2>/dev/null <"/proc/$2/cmdline" || return 1
  [[ "${a[*]}" == *"${CMD[$1]}" ]]
}

# shellcheck disable=SC2016 # les apostrophes sont voulues : $0 se développe dans le bash enfant, qui reçoit le port.
sonde() { timeout "$PROBE_TIMEOUT" bash -c ': > /dev/tcp/127.0.0.1/"$0"' "$1" 2>/dev/null; }

# SIGTERM, 5 secondes de grâce (contrat cible §3), puis SIGKILL.
neutraliser() {
  local i
  journal "$1" "NEUTRALISE SIGTERM"
  kill -TERM "$2" 2>/dev/null || true
  for ((i = 0; i < 50; i++)); do
    if ! existe "$1" "$2"; then return 0; fi
    sleep 0.1
  done
  journal "$1" "NEUTRALISE SIGKILL"
  kill -KILL "$2" 2>/dev/null || true
}

# --- Bloc 3 : nettoyeur ---
nettoyer() {
  set +e
  trap '' INT TERM
  local id pid
  for id in "${IDS[@]}"; do
    pid=""
    if [ -f "$RT/$id.pid" ]; then pid=$(<"$RT/$id.pid"); fi
    if existe "$id" "$pid"; then neutraliser "$id" "$pid"; fi
  done
  rm -f "$RT"/*.pid "$RT"/*.stop "$RT"/*.fails
  journal allwatch ARRET
}
trap nettoyer EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- Bloc 4 : moteur de la machine à états ---
lancer() {
  local -a argv
  read -ra argv <<<"${CMD[$1]}"
  "${argv[@]}" &
  echo "$!" >"$RT/$1.pid"
  CHILD[$1]=1
}

evaluer() {
  local id=$1 pid="" rc=1 force=0 n
  if [ -f "$RT/$id.pid" ]; then pid=$(<"$RT/$id.pid"); fi

  if existe "$id" "$pid"; then
    if sonde "${PORT[$id]}"; then
      SUSPECT[$id]=0
      if [ "${GEL[$id]}" = 1 ]; then GEL[$id]=0; journal "$id" RETABLI; fi
      return 0
    fi
    if [ "${SUSPECT[$id]}" = 0 ]; then
      SUSPECT[$id]=$EPOCHSECONDS; journal "$id" PLANTE; return 0
    fi
    if ((EPOCHSECONDS - ${SUSPECT[$id]} < GRACE)); then return 0; fi
    # Une cible peut écrire dans une base sans répondre : l'opérateur choisit de ne pas la tuer.
    if [ "$ON_FREEZE" = alert ]; then
      if [ "${GEL[$id]}" = 0 ]; then GEL[$id]=1; journal "$id" "ALERTE GEL : port muet, cible vivante, aucune neutralisation (ON_FREEZE=alert)"; fi
      return 0
    fi
    neutraliser "$id" "$pid"; force=1
  fi

  SUSPECT[$id]=0; GEL[$id]=0
  # Un PID repris d'un superviseur précédent n'est pas un enfant : pas de code de sortie, donc un échec.
  if [ "${CHILD[$id]}" = 1 ]; then wait "$pid" 2>/dev/null && rc=0 || rc=$?; fi
  if [ "$force" = 1 ]; then rc=1; fi

  if [ -e "$RT/$id.stop" ]; then
    rm -f "$RT/$id.stop" "$RT/$id.pid"; FIN[$id]=1; journal "$id" QUITTE; return 0
  fi
  if [ "$rc" != 0 ] && [ "$force" = 0 ]; then journal "$id" "CRASHE code=$rc"; fi
  if [ "${POL[$id]}" = transient ] || { [ "$rc" = 0 ] && [ "${POL[$id]}" = on-failure ]; }; then
    rm -f "$RT/$id.pid"; FIN[$id]=1; journal "$id" QUITTE; return 0
  fi

  n=$(awk -v c=$((EPOCHSECONDS - RESTART_WINDOW)) '$1 >= c { n++ } END { print n + 0 }' "$RT/$id.fails")
  if [ "$n" -ge "$MAX_RESTARTS" ]; then
    rm -f "$RT/$id.pid"; FIN[$id]=1
    journal "$id" "ALERTE VERROU_CRITIQUE : $n relances en ${RESTART_WINDOW}s, relance suspendue"
    return 0
  fi
  echo "$EPOCHSECONDS" >>"$RT/$id.fails"
  journal "$id" RELANCE
  lancer "$id"
}

journal allwatch "DEMARRAGE $CONF"
for id in "${IDS[@]}"; do
  : >>"$RT/$id.fails"
  pid=""
  if [ -f "$RT/$id.pid" ]; then pid=$(<"$RT/$id.pid"); fi
  if existe "$id" "$pid"; then journal "$id" "ADOPTE pid=$pid"; else lancer "$id"; journal "$id" DEMARRE; fi
done

while :; do
  sleep "$POLL_SECONDS"
  for id in "${IDS[@]}"; do
    if [ "${FIN[$id]}" = 0 ]; then evaluer "$id"; fi
  done
done
