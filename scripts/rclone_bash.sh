#!/usr/bin/env bash

# globals
pkg=$(basename $0)
pkg_path=$(cd $(dirname $0); pwd -P)
clear=$(which clear)

# formatting
source $pkg_path/std_functions.sh
source $pkg_path/colors.sh
frame=$(echo -e ${brightblue})
reset=$(tput sgr0)
bodytext=$(echo -e ${reset}${a_wgray})
sp="${frame}|${bodytext}"

#
SOURCE_DEFAULT="/home/blake/Downloads/gdrive"
DESTINATION_DEFAULT="/home/blake/Documents/Trading/STATIC PORTFOLIO DOCUMENTATION"

# error codes
E_BADARG=8                  # exit code if bad input parameter
                            # given profilename from local awscli configuration

# --- declarations ------------------------------------------------------------


function help_menu(){
    cat <<EOM
${bodytext}
                        Help Contents
                        -------------

  ${title}SYNOPSIS${bodytext}

            $  sh ${title}rclone_bash.sh${bodytext}   --download | --accounts

                    -r | --remote   <${yellow}REMOTE${bodytext}>
                   [-d | --download ]
                   [-h | --help     ]
                   [-l | --list     ]
                   [-v | --verify   ]

  ${title}OPTIONS${bodytext}

      ${title}-r | --remote${bodytext}:  Remote file share (local or network location).

      ${title}-d | --download${bodytext}: Download complete file set from <${yellow}REMOTE${bodytext}>.
                  must be used in conjunction with --remote parameter.

      ${title}-h | --help${bodytext}:  Print this help menu

      ${title}-l | --list${bodytext}:  List remotes available on this local machine.

      ${title}-v | --verify${bodytext}:  Verify installation of the rclone application
                  on local machine.

EOM
    #
    # <-- end function help -->
}

function parse_parameters(){
    if [[ ! $@ ]]; then
        help_menu
        exit 0
    else
        while [ $# -gt 0 ]; do
            case $1 in
                -r | --remote)
                    REMOTE="$2"
                    shift 2
                    ;;

                -c | --copy)
                    OPERATION="COPY"
                    shift 1
                    ;;

                -l | --list)
                    OPERATION="LIST"
                    shift 1
                    ;;

                -h | --help)
                    help_menu
                    shift 1
                    exit 0
                    ;;

                -v | --verify)
                    verify_installation
                    shift 1
                    ;;

                *)
                    echo "Unknown parameter ($1). Exiting"
                    exit $E_BADARG
                    ;;
            esac
        done
    fi
    if [ ! $PROFILE ] && [ ! $ACCTFILE ]; then
        PROFILE="default"
    elif [ $PROFILE ] && [ $ACCTFILE ]; then
        std_error_exit "You cannot provide both an account file and a PROFILE parameter. Exit"
    fi
    if [ $PROFILE ]; then
        ACCOUNTS=( "$PROFILE" )
    fi
    #
    # <-- end function parse_parameters -->
}


function download_from_remote(){
    ## calculates number of unique regions lambda functions found ##
    local remote_fs="$1"
    local write_dir=$(pwd)
    local rclone=$(which rclone)
    #
    $rclone copy $remote_fs $write_dir
    #
    # <-- end function download_from_remote -->
}


function rsync_2local_target() {
    ## rsync fs from source dir to destination dir on local machine ##
    local source="$1"
    local destination="$2"
    #
    rsync -arv $source/* $destination/ --delete
}


function date_display(){
    ## return proper date string to display ##
    local datetime="$1"
    local dt=$(( $(date -u +%s) - $(date --date="$datetime" +%s) ))
    local oneday=$(( 24 * 60 * 60 ))
    if (( $dt <= $oneday )); then
        printf '%s_ago\n' "$(echo $(convert_time $dt) | awk -F ',' '{print $2","$3}')"
    else
        echo $(date --date=${ARR_CTIME[$i]} +"%Y-%m-%d")
    fi
}

function verify_installation(){
    ## verifies installation of required dependency rclone
    program="rclone"
    if [[ $(command -v $program) ]]; then
        std_message "$program installed" "INFO"
    else
        std_message "$program not installed or not in your PATH" "WARN"
    fi
}

#
# MAIN  ------------------------------------------------------------------
#

parse_parameters $@


exit 0
