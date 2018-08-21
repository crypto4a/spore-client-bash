#!/bin/bash -e

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#       ___           ___         ___           ___           ___       #
#      /  /\         /  /\       /  /\         /  /\         /  /\      #
#     /  /:/_       /  /::\     /  /::\       /  /::\       /  /:/_     #
#    /  /:/ /\     /  /:/\:\   /  /:/\:\     /  /:/\:\     /  /:/ /\    #
#   /  /:/ /::\   /  /:/~/:/  /  /:/  \:\   /  /:/~/:/    /  /:/ /:/_   #
#  /__/:/ /:/\:\ /__/:/ /:/  /__/:/ \__\:\ /__/:/ /:/___ /__/:/ /:/ /\  #
#  \  \:\/:/~/:/ \  \:\/:/   \  \:\ /  /:/ \  \:\/:::::/ \  \:\/:/ /:/  #
#   \  \::/ /:/   \  \::/     \  \:\  /:/   \  \::/~~~~   \  \::/ /:/   #
#    \__\/ /:/     \  \:\      \  \:\/:/     \  \:\        \  \:\/:/    #
#      /__/:/       \  \:\      \  \::/       \  \:\        \  \::/     #
#      \__\/         \__\/       \__\/         \__\/         \__\/      #
#                                                                       #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# import utilities
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

###########################
# CONSTANTS & VARIABLES
###########################

# Script version
readonly VERSION=0.0.1

# List of required programs
readonly REQUIRED=(curl openssl)

# Script name
readonly SCRIPT_NAME=${0##*/}

# # List of options (long form)
# readonly LONG_OPTS=(help version)

# List of options (short form)
readonly OPTSTRING=:hvice:

# Formating sequences
normal=$(echo -e "\033[0m")
underline=$(echo -e "\033[4m")
bold=$(echo -e "\033[1m")

###########################
# help command
###########################
help_command() {
    cat <<END

USAGE:
    $SCRIPT_NAME ${underline}${bold}[options]${normal} \
${underline}[url]${normal}

OPTIONS:
    -h      Display detailed help.

    -v      Display version information.

    -i      Perform a getInfo request.

    -c      Perform a getCertChain request.

    -e ${underline}challenge${normal}
            Perform a getEntropy request with the given challenge.

END
}

###########################
# version command
###########################
version_command() {
    echo "$SCRIPT_NAME version $VERSION"
}

###########################
# default command
###########################
default_command() {
    help_command
}

##########################
# verify dependencies
##########################
verify_dependencies() {
    if ["$(which openssl)" = ""]
    then
        echo "This script requires openssl, please resolve and try again."
        exit 1
    fi 

    if ["$(which curl)" = ""]
    then
        echo "This script requires curl, please resolve and try again." >&2
        exit 1
    fi
}

##########################
# getInfo request
##########################
do_getInfo() {
    curl -s -w "\n" -X POST $1/getInfo
}

##########################
# getCertChain request
##########################
do_getCertChain() {
    curl -s -w "\n" -X POST $1/getCertChain
}

##########################
# getEntropy request
##########################
do_getEntropy() {
    curl -s -w "\n" -X POST $2/getEntropy?challenge=$1
}


##########################
# Main program
##########################
main() {

    # Required programs
    check_required $REQUIRED

    # Parse options
    command="default_command"
    url_required=0
    while getopts $OPTSTRING opt
    do
        case $opt in
            h)  
                command="help_command"
                ;;
            v)  
                command="version_command"
                ;;
            i)
                command="do_getInfo"
                url_required=1
                ;;
            c)
                command="do_getCertChain"
                url_required=1
                ;;
            e)
                command="do_getEntropy \"$OPTARG\""
                url_required=1
                ;;
            \?)
                err "Illegal option: -$OPTARG"
                exit 1
                ;;
            :)
                err "Option -$OPTARG requires an argument."
                exit 1
                ;;
        esac

    done  

    shift $((OPTIND-1))

    # Test if URL is present
    if (( url_required ))
    then
        [[ -z "$1" ]] && err "A URL is required to perform this command." \
        && exit 1

        # Trim trailing slash
        url=$(echo $1 | sed 's/\/$//')
    fi

    # Execute 
    eval $command $url >&1
}

main "$@"
exit 0
