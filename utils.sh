#!/bin/bash -e

# Print message to STDERR.
err() {
    echo -e "\033[0;31mERROR: $@\033[0m" >&2
}

# Given a list of program names, makes sure they are available.
check_required() {
    local e=0
    for prog in "$@"
    do
        type $prog >/dev/null 2>&1 || {
            e=1 && 
            err "This script requires $prog, please resolve and try again."
        }
    done
    [[ $e < 1 ]] || exit 2
}
