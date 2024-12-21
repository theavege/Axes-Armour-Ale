#!/usr/bin/env bash

function priv_clippit
(
    cat <<EOF
Usage: bash ${0} [OPTIONS]
Options:
    build   Build program
EOF
)

function priv_fpcbuild
(
    printf "Compiling Axes, Armour & Ale..."
    mkdir -p ../source/lib/x86_64-linux
    if pushd ../source; then
        fpc Axes.pas -MObjFPC -Scghi -CX -Cg -Os3 -Xs -XX -l -vewnhibq -Filib/x86_64-linux -Fientities -Fidungeons -Fudungeons -Fuentities -Fuitems -Fuplayer -Fuscreens -Fuvision -Fuentities/animals -Fuentities/bugs -Fuentities/fungus -Fuentities/gnomes -Fuentities/hobs -Fuitems/armour -Fuitems/macguffins -Fuitems/weapons -Fuentities/bogles -Fuentities/undead -Fuentities/goblinkin -Fuentities/troglodytes -Fuentities/npc -Fuitems/traps -Fu. -FUlib/x86_64-linux -FE. -oAxes
    fi
    printf "\tComplete.\n"
)

function priv_fpcdebug
(
    printf "Compiling Axes, Armour & Ale - DEBUG VERSION\n"
    mkdir -p ../source/lib/x86_64-linux
    if pushd ../source; then
        fpc Axes.pas -Mfpc -Scaghi -Cg -CirotR -O1 -gw2 -godwarfsets -gl -gh -Xg -gt -l -vewnhibq -Filib/x86_64-linux -Fientities -Fudungeons -Fuentities -Fuitems -Fuplayer -Fuscreens -Fuvision -Fuentities/animals -Fuentities/fungus -Fuentities/gnomes -Fuentities/hobs -Fuitems/armour -Fuitems/macguffins -Fuitems/weapons -Fuitems/traps -Fuentities/bugs -Fuentities/bogles -Fuentities/undead -Fuentities/goblinkin -Fuentities/troglodytes -Fuentities/npc -Fu. -FUlib/x86_64-linux -FE. -oAxes
    fi
    printf "\tcleaning up files....\n"
    delp -r ./
    printf "\tupdating tags file...\n"
    ctags -R --languages=Pascal
    printf "Complete.\n"
)

function priv_main
(
    set -euo pipefail
    if ((${#})); then
        case ${1} in
            build) priv_fpcbuild ;;
            debug) priv_fpcdebug ;;
            find) grep --color=always --include=\*.pas -rnw . -e "${2}" ;;
            format) ptop -c ptop.cfg "${2}"{,} ;;
            tidyUp) delp -r ./ && ctags -R --languages=Pascal ;;
            *) priv_clippit ;;
        esac
    else
        priv_clippit
    fi
)

priv_main "${@}" #>/dev/null
