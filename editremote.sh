#!/bin/sh

# Edit a file remotely over sshfs using a defined editor or the one specified with -e

# TODO:  Make sure spaces in path and file are safe and work

# Don't edit this script!  To specify your personal default editor, create a file named
# ~/.editremote.sh and put these two variables in it with the appropriate values.

# Default editor
editor=vi
# Do we wait for the editor proces to return or just prompt the user to hit enter
# IE:  If your editor forks into the background, set this to 1
prompt_for_unmount=0

version=1.0

evar=0
fileurl=""
localfile=""
sshfs=0

# Look to see if we have a config file, if so, use it
if [ -e ~/.editremote.sh ]; then
    source ~/.editremote.sh
fi

# Handle -e paramter in any order, ugly but works
for var in "$@"
do
    if [ "${evar}" == "1" ]; then
        editor=${var}
        evar=0
    fi

    if [ "${var}" == "-e" ]; then
        # If we see -e, the next var is going to be the editor to use
        evar=1
        # And to make sure we don't unmount immediately, set the unmount var to 1
        prompt_for_unmount=1
    fi

    if [[ "${var}" =~ ^(.*):(.*) ]]; then
        fileurl=${var}
        sshfs=1
    fi

    # This is goofy, but track a localfile in case we don't wind up detecting a remote file path
    if [ ${sshfs} == 0 ]; then
        localfile=${var}
    fi
done

if [ ! -x "$(type -p ${editor})" ]; then
    echo "${editor} not found in path, exiting"
    exit
fi

if [ "${fileurl}" == "" ] && [ "${localfile}" == "" ]; then
    echo "No file to edit found; exiting"
    exit
fi

# Common function to clean up and exit
function cleanexit
{
    cleandir=$1
    if [ "${cleandir}" != "" ]; then
        fusermount -uz "${cleandir}"
        rmdir "${cleandir}"
    fi
    exit
}

# Common function to test to make sure we can edit the file or create a new file in this path
function testedit
{
    testfile="$1"

    if [ -e ${testfile} ]; then
        # For some reason [ -w ] doesn't work; use touch
        touch -ac "${testfile}" >/dev/null 2>&1
        rc=$?
        if [ ${rc} != 0 ]; then
            echo ""
            echo "WARNING!  No permission to edit ${testfile}!"
            sleep 1s
        fi
    else
        tmpfile=$(mktemp -q ${testfile}.XXXXXXX)
        touch "${tmpfile}" >/dev/null 2>&1
        rc=$?
        if [ ${rc} != 0 ]; then
            echo "FAILURE!  No permission to write to path and ${testfile} does not exist!"
            cleanexit
        else
            rm "${tmpfile}"
        fi
    fi
}

if [ ${sshfs} == 1 ]; then
    # Make sure sshfs is available
    if [ ! -x "$(type -p sshfs)" ]; then
        echo "sshfs is not installed; exiting"
        exit
    fi

    # Start breaking up the fileurl
    user=""
    url=""
    fullpath=""
    dir=""
    userstring=""
    remote=""

    # Break up the file url
    if [[ ${fileurl} =~ \@ ]]; then
        user=`echo ${fileurl} | cut -f 1 -d "@"`
        url=`echo ${fileurl} | cut -f 2 -d "@"`
    else
        url=${fileurl}
    fi

    # Now get the directory path out for sshfs
    remote=`echo ${url} | cut -f 1 -d ":"`
    fullpath=`echo ${url} | cut -f 2 -d ":"`
    filename=`basename "${fullpath}"`
    dir=$(dirname "${fullpath}")

    if [[ "${dir}" =~ \~ ]]; then
        echo "Cannot use relative paths such as ~/ please use full path"
        exit
    fi

    if [ "${user}" != "" ]; then
        userstring="${user}@"
    fi

    # Create a somewhat friendly tmp path
    tmpdirstring=${dir//\//_}
    tmpdir=`mktemp -d "/tmp/XXXX.${remote}${tmpdirstring}"`

    # Make sure we have everything we need
    if [ "${remote}" != "" ] && [ "${dir}" != "" ] && [ "${filename}" != "" ]; then
        sshfs "${userstring}${remote}:${dir}" "${tmpdir}"
        rc=$?
        if [ ${rc} != 0 ]; then
            echo "FAILURE!  sshfs failed, invalid hostname or other error?  Attempted the following:"
            echo "sshfs ${userstring}${remote}:${dir} ${tmpdir}"
            cleanexit
        fi

        # Test if we can write to this path and/or file and warn if not
        remotefile=${tmpdir}/${filename}
        testedit ${remotefile}

        ${editor} "${remotefile}"
        pid=$!
        # We have to handle editors that launch in the the background by watching their pid
        # But if the editor is already running, like sublime, we get a temporary pid
        if [ ${prompt_for_unmount} == 0 ]; then
            wait ${pid}
        else
            # If all else fails, we just prompt to user to let us finish up..  gross
            echo -n "Hit enter when done editing and file is closed.. "
            read
        fi
        cleanexit "${tmpdir}"
    else
        echo "Something went wrong..."
        echo "remote: [${remote}] dir: [${dir}] filename: [${filename}]"
        cleanexit "${tmpdir}"
    fi
else
    testedit ${localfile}
    ${editor} "${localfile}"
fi
