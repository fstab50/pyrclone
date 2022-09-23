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
E_PROFILENAME=9             # exit code if authenication to aws account fails
                            # given profilename from local awscli configuration
GCREDS=""                   # use of gcreds for temp credentials, set to false otherwise

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

                -v | --verify-installation)
                    PROFILE="$2"
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


function print_table(){
    ## output table of results ##
    local sum
    local pct
    local name
    local rgn
    local acct
    local mod
    local rt
    local mem
    local to

    # variable width headings
    sum=$(( 2 + 41 + 2 + 14 + 2 + 17 + 2 + 16 + 2 + 10 + 2 + 8 + 2 + 10 + 2 + 11 + 2))

    rgn="14"    # region spacing
    #acct=17     # account alias spacing
    rt="10"     # runtime spacing
    mem="8"     # mem spacing
    to="9"      # to spacing
    pkg="8"    # code pkg
    mod="16"    # modified time

    # age header spacing
    pct=$(echo "scale=2;25/$sum" | bc -l)
    acct="$(float2int $(echo "scale=0;$pct*$twidth" | bc -l))"

    # function name spacing
    pct=$(echo "scale=2;41/$sum" | bc -l)
    name=$(( $twidth - $rgn - $acct - $mod - $rt - $mem - $to - $pkg - $((6*3 + 7)) ))

    awk '{ printf "  %-2s %-'$name'.'$(($name-1))'s %-2s %-'$rgn's %-2s %-'$acct's %-2s %-'$mod's %-2s %-'$rt's %-2s %-'$mem's %-2s %-'$to's %-2s %-'$pkg's %-2s\n", \
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17}' .report.tmp
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

#
# MAIN  ------------------------------------------------------------------
#

parse_parameters $@

# set tmp in ram
set_tempdir

for profile in ${ACCOUNTS[@]}; do
    # set profile name prefix, if required
    profile="$(profilename_prefix $profile)"
    # status msg
    if [ $(echo $profile | grep gcreds) ]; then
        stripped="$(echo $profile | awk -F '-' '{for (i=2; i<NF; i++) printf $i "-"; print $NF}')"
    else
        stripped=$profile
    fi

    # execute operations which require authentication to AWS
    if ! authenticated $profile; then exit $E_PROFILENAME; fi

    # print status msg
    std_message "Auditing account ${bold}$stripped${reset}.  Please wait..." "INFO"

    if [ ! $REGION ]; then
        REGIONS="$(get_regions $profile)"
    else
        REGIONS=( "$REGION" )
    fi

    #for PROFILE in ${ACC}
    for region in ${REGIONS[@]}; do
        aws lambda list-functions  --region $region --profile $profile --output json > .jsonoutput.tmp
        # parse json
        arr_name=( $(jq -r '.Functions[].FunctionName' .jsonoutput.tmp) )
        arr_ctime=($(jq -r '.Functions[].LastModified' .jsonoutput.tmp) )
        arr_runtime=($(jq -r '.Functions[].Runtime' .jsonoutput.tmp) )
        arr_mem=($(jq -r '.Functions[].MemorySize' .jsonoutput.tmp) )
        arr_to=($(jq -r '.Functions[].Timeout' .jsonoutput.tmp) )
        arr_size=($(jq -r '.Functions[].CodeSize' .jsonoutput.tmp) )

        # set location
        ct=0
        declare -a arr_location
        arr_location=( )
        declare -a arr_account
        arr_account=( )
        account_name=$(aws iam list-account-aliases --profile $profile | jq -r .AccountAliases[0])

        while (( $ct < ${#arr_name[@]} )); do
            # account_name
            arr_account=( ${arr_account[@]} "$account_name" )
            arr_location=( ${arr_location[@]} "$region" )
            ct=$(( $ct + 1 ))
        done

        # parse json
        ARR_NAME=( ${ARR_NAME[@]} ${arr_name[@]} )
        ARR_LOC=( ${ARR_LOC[@]} ${arr_location[@]} )
        ARR_ACCOUNT=( ${ARR_ACCOUNT[@]} ${arr_account[@]} )
        ARR_CTIME=(${ARR_CTIME[@]} ${arr_ctime[@]} )
        ARR_RUNTIME=( ${ARR_RUNTIME[@]} ${arr_runtime[@]} )
        ARR_MEM=( ${ARR_MEM[@]} ${arr_mem[@]} )
        ARR_TO=( ${ARR_TO[@]} ${arr_to[@]} )
        ARR_SIZE=( ${ARR_SIZE[@]} ${arr_size[@]} )
    done
done

# clear screen messages
$clear

num_locations=$(calculate_unique_locations ARR_LOC[@])

# header
if [ $REGION ]; then
    printf "\n${title}AWS LAMBDA AUDIT${bodytext} : ${brightblue}${REGIONS[@]}${bodytext}  | $ast*${bodytext}sort\n" | indent25
else
    printf "\n${title}AWS LAMBDA AUDIT${bodytext} : ${brightblue}ALL Regions${bodytext}  | $ast*${bodytext}sort\n" | indent25
fi
print_header "  $sp FunctionName $sp Region $sp Account $sp Modified* $sp  Runtime $sp  Mem(MB) $sp T.O.(sec) $sp Code(KB) $sp" "$twidth" .report.tmp

MAXCT=${#ARR_NAME[@]}
i=0
while (( $i < $MAXCT )); do
    echo "$sp ${ARR_NAME[$i]} $sp ${ARR_LOC[$i]} $sp ${ARR_ACCOUNT[$i]} $sp "${tile}$(date_display "${ARR_CTIME[$i]}")" $sp \
          ${ARR_RUNTIME[$i]} $sp ${ARR_MEM[$i]} $sp ${ARR_TO[$i]} $sp \
          $((${ARR_SIZE[$i]}/1024)) $sp" >> .body.tmp
    # incr ct
    i=$(( $i+1 ))
done

if [ $FUNCTION_NAME ]; then
    cat .body.tmp | sort -k8 -r | grep -i $FUNCTION_NAME >> .report.tmp
else
    cat .body.tmp | sort -k8 -r >> .report.tmp
fi

# print tabular body of report
print_table

SUM=0
for num in ${ARR_SIZE[@]}; do
    SUM=$(( $SUM + $num))
done
ASUM=$(($SUM/1024/1024))

py27=0; py36=0; py37=0; py38=0; node=0; go=0; java=0

for rt in ${ARR_RUNTIME[@]}; do
    case $rt in
        python2.7)
            py27=$(( $py27 + 1))
            ;;
        python3.6)
            py36=$(( $py36 + 1))
            ;;
        python3.7)
            py37=$(( $py37 + 1))
            ;;
        python3.8)
            py38=$(( $py38 + 1))
            ;;
        nodejs | nodejs6.10 | nodejs4.3)
            node=$(( $node + 1))
            ;;
        java[1-9])
            java=$(( $java + 1))
            ;;
        go[1-9].X)
            go=$(( $go + 1))
        ;;
    esac
done


if [ $REGION ]; then
    print_footer "Lambda Summary:\n\n\t\t${title}$MAXCT${UNBOLD}${bodytext} functions in ${title}$num_locations${bodytext} region [${brightblue}${REGIONS[@]}${bodytext}]  \
        \n\t\t${title}$ASUM${bodytext} MB Total Code Package Size \n
        \nRuntime Types:\n\t\t${title}$py27${bodytext} Python2.7 \n \
        \n\t\t${title}$py36${bodytext} Python3.6 \n \
        \n\t\t${title}$py37${bodytext} Python3.7 \n \
        \n\t\t${title}$py38${bodytext} Python3.8 \n \
        \n\t\t${title}$node${bodytext} Nodejs \n \
        \n\t\t${title}$java${bodytext} Java \n \
        \n\t\t${title}$java${bodytext} Go 1.X \n" $twidth
else
    print_footer "Lambda Summary:\n\n\t\t${title}$MAXCT${UNBOLD}${bodytext} functions in ${title}$num_locations${bodytext} regions  \
        \n\t\t${title}$ASUM${bodytext} MB Total Code Package Size \n
        \nRuntime Types:\n\t\t${title}$py27${bodytext} Python2.7 \n \
        \n\t\t${title}$py36${bodytext} Python3.6 \n \
        \n\t\t${title}$py37${bodytext} Python3.7 \n \
        \n\t\t${title}$py38${bodytext} Python3.8 \n \
        \n\t\t${title}$node${bodytext} Nodejs \n \
        \n\t\t${title}$java${bodytext} Java \n \
        \n\t\t${title}$java${bodytext} Go 1.X \n" $twidth
fi

# clean up
rm .report.tmp .body.tmp .jsonoutput.tmp

exit 0
