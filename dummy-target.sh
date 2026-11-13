#!/usr/bin/env bash
# MIT License — Copyright (c) 2026 Ronan Davalan (texte complet : fichier LICENSE)
#
# dummy-target.sh — simule une cible supervisée qui écoute sur un port TCP
#
# Pourquoi : éprouver le superviseur sans dépendre d'une vraie application, en
#     provoquant à la demande une fin propre, un blocage ou un crash.
#
# Entrée / sortie : dummy-target.sh <port>, au premier plan.
#     SIGTERM : arrêt propre, code 0 ; SIGUSR1 : blocage, l'écoute se ferme et
#     le processus reste vivant ; SIGUSR2 : crash immédiat, code 1.
set -euo pipefail

port="${1:?usage : dummy-target.sh <port>}"
bloque=0

# nc se lie sans erreur à un port déjà écouté (SO_REUSEPORT) : sans cette garde,
# un doublon passerait pour sain.
if (: >/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then exit 1; fi

# Boucle locale seulement : la maquette n'a aucune raison d'être joignable du
# réseau. pdeathsig : un kill -9 du script libère aussi le port, sans quoi la
# relance échouerait sur « Address already in use ».
setpriv --pdeathsig KILL nc -lk 127.0.0.1 "$port" </dev/null >/dev/null &
ecoute=$!

trap 'kill "$ecoute" 2>/dev/null || true; exit 0' TERM
trap 'bloque=1; kill "$ecoute" 2>/dev/null || true' USR1
trap 'kill "$ecoute" 2>/dev/null || true; exit 1' USR2

# Si l'écoute meurt hors blocage voulu (port déjà pris), la maquette sort en
# erreur : une cible qui n'écoute pas ne doit pas paraître vivante.
while [ "$bloque" = 1 ] || kill -0 "$ecoute" 2>/dev/null; do
  sleep 0.2
done
exit 1
