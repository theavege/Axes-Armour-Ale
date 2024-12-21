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
    printf "\x1b[33mCompiling Axes, Armour & Ale...\x1b[0m\n"
    mkdir -p source/lib/x86_64-linux
    if pushd source; then
        fpc Axes.pas -MObjFPC -Scghi -CX -Cg -Os3 -Xs -XX -l -vewnhibq -Filib/x86_64-linux -Fientities -Fidungeons -Fudungeons -Fuentities -Fuitems -Fuplayer -Fuscreens -Fuvision -Fuentities/animals -Fuentities/bugs -Fuentities/fungus -Fuentities/gnomes -Fuentities/hobs -Fuitems/armour -Fuitems/macguffins -Fuitems/weapons -Fuentities/bogles -Fuentities/undead -Fuentities/goblinkin -Fuentities/troglodytes -Fuentities/npc -Fuitems/traps -Fu. -FUlib/x86_64-linux -FE. -oAxes
    fi
    printf "\x1b[32m\t...complete!\x1b[0m\n"
)

function priv_fpcdebug
(
    printf "Compiling Axes, Armour & Ale - DEBUG VERSION\n"
    mkdir -p source/lib/x86_64-linux
    if pushd source; then
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
    if ! (which lazbuild); then
        source '/etc/os-release'
        case ${ID:?} in
            debian | ubuntu)
                printf '\x1b[32mInstall Lazarus.\x1b[0m\n' 1>&2
                sudo apt-get update
                sudo apt-get install -y lazarus{-ide-qt5,}
                ;;
        esac
    fi
    if ((${#})); then
        case ${1} in
            build) priv_fpcbuild 1>&2 ;;
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

priv_main "${@}" >/dev/null
