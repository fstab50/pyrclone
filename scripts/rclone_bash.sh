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

# set defaults
SOURCE_DEFAULT="/home/blake/Downloads/gdrive"
DESTINATION_DEFAULT="/home/blake/Documents/Trading/STATIC PORTFOLIO DOCUMENTATION"

# Set excecutables
rclone=$(command -v rclone)
rsync_bin=$(command -v rsync)
LOG_FILE=$HOME/logs/rclone_bash.log

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

            $  sh ${title}$pkg${bodytext}   --list || --copy || --verify || --download --remote

                    -r | --remote   <${yellow}REMOTE${bodytext}>
                   [-c | --copy <${yellow}SOURCE${bodytext}> <${yellow}DESTINATION${bodytext}> ]
                   [-d | --download ]
                   [-h | --help     ]
                   [-l | --list     ]
                   [-v | --verify   ]

  ${title}OPTIONS${bodytext}

      ${title}-c | --copy${bodytext}: Copy complete file set from <${yellow}REMOTE${bodytext}>. Must be used
                    in conjunction with --remote parameter.

      ${title}-d | --download${bodytext}: Copy complete file set from <${yellow}REMOTE${bodytext}> to /tmp
                    directory on local machine.

      ${title}-h | --help${bodytext}:  Print this help menu

      ${title}-l | --list${bodytext}:  List remotes available on this local machine.

      ${title}-r | --remote${bodytext}:  Remote file share (local or network location).

      ${title}-v | --verify${bodytext}: Verify installation of the rclone application
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
                    if [ "$2" ] && [ "$3" ]; then
                        SOURCE="$2"
                        DESTINATION="$3"
                        echo "SOURCE: $SOURCE, DESTINATION:  $DESTINATION."; exit 0
                        shift 3
                    else
                        std_error_exit "Both source and destation must be provided after the --copy parameter" "1"
                    fi
                    ;;

                -d | --download)
                    OPERATION="DOWNLOAD"
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
                    verify_installation 'rclone'
                    verify_installation 'rsync'
                    exit 0
                    ;;

                *)
                    echo "Unknown parameter ($1). Exiting"
                    exit $E_BADARG
                    ;;
            esac
        done
    fi
    if [ $OPERATION = "DOWNLOAD" ] && [ ! "$REMOTE" ]; then
        std_error_exit "You must provide a remote fileshare location (--remote <fileshare>) from which to copy. Exit" "1"
        #std_error_exit "You cannot use --remote with the list operation. Exit" "1"
    fi
    #
    # <-- end function parse_parameters -->
}


function download_from_remote(){
    ## calculates number of unique regions lambda functions found ##
    local from_remote="$1"
    local to_localdir="/tmp"
    local rclone=$(command -v rclone)
    #
    std_message "Downloading from $from_remote to $to_localdir." "INFO"
    $rclone copy "$from_remote" "$to_localdir"
    std_message "Download completed."  "INFO"
    #
    # <-- end function download_from_remote -->
}


function rsync_2local_target() {
    ## rsync fs from source dir to destination dir on local machine ##
    local source="$1"
    local destination="$2"
    #
    $rsync_bin -arv "$source"/ "$destination"/ --delete
    #
    # <-- end function rsync_2local_target -->
}


function verify_installation(){
    ## verifies installation of required dependency rclone
    local program="$1"
    if [[ $(command -v "$program") ]]; then
        std_message "$program is installed." "INFO"
        return 0
    else
        std_message "$program not installed or not in your PATH. Exit." "WARN"
        return 1
    fi
}

#
# MAIN  ------------------------------------------------------------------
#


parse_parameters $@

if ! verify_installation 'rclone' || ! verify_installation 'rsync'; then
    exit 1
fi

# begin
if [ $OPERATION = "DOWNLOAD" ] && [ "$REMOTE" ]; then

    download_from_remote "$REMOTE"

elif [ $OPERATION = "LIST" ] && [ "$REMOTE" ]; then

    $rclone ls "$REMOTE"

elif [ $OPERATION = "LIST" ] && [ ! "$REMOTE" ]; then

    $rclone ls "$REMOTE"

elif [ $OPERATION = "COPY" ]; then

    std_message "Beginning Copy operation from $1 to $2"

fi

exit 0
