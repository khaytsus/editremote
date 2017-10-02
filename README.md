Edit a file remotely over sshfs
================

This script makes it easy to locally edit a file over ssh, using sshfs.  Since the script mounts the remote path using sshfs and edits that file directly (no copying the file locally, etc), there should be no issues with symlinks, selinux contexts, etc.  Note that the editor is executed on the _local_ machine.

The script sanity checks the fileurl (ie:  user@machine:/path/to/file) and then breaks it apart and creates a temporary directory in /tmp and uses sshfs to mount the remote path and edits the file.  Along the way many checks are done to ensure that the file exists and is writable.  If the file does not exist it ensures that the path is writable.  At this time the script only warns if the file cannot be written, but fails if the file does not exist and the path cannot be written to.

Specifying the username is optional in the fileurl; if not specified the user is assumed to be the current user.

The full remote file path must be specified, ie:  user@machine:~/fileinhomedir.txt will not work.  The script catches this specific example but there may be others, so always specify the full absolute path to the filename.

The script also supports local files.  If a remote path is not detected, the script will edit the file directly (no sshfs, etc).  You could potentially use this script as your default editor for both local and remote files and not have to run a different editor/script based on the file location.

You can specify which editor you wish to use passing the -e flag into the script which will use the specified editor for this session, ie:  editeremote.sh -e nano user@machine:/path/to/file   Note:  If -e is specified, prompt_for_unmount (see below) is set to 1 to ensure the sshfs isn't unounted too early.

### General Usage

#### Remote file usage
editremote.sh user@remote.com:/home/user/file.txt

#### File and/or path with spaces
If editing a path or filename with spaces, enclose the whole thing in quotes.

editremote.sh "user@remote.com:/home/user/spaced dir/spaced file.txt"

#### Specify editor to use 
If you want to use a specific editor for most edits, configure the default editor as noted in the next section.  For one-off editor changes, you can pass the -e flag into the command. 

editremote.sh -e vim user@remote.com:/home/user/file.txt

### Configuration of default editor
To specify a default editor you can create a file named ~/.editremote.sh with two variables in it.

* editor="/path/to/editorbin"
  * Path to the editor of your choice
* prompt_for_unmount=0
  * 0 means do not prompt to unount sshfs, it will unmount as soon as the editor exits
  * 1 means to prompt the user to hit enter to unmount sshfs (for editors which fork to the background)

Example:

editor=sublime  
prompt_for_unmount=1  

### Use Cases
My primary use case for this script is editing Perl on a remote Raspberry Pi in Sublime so I have all of my favorite plugins and such available without copying files back and forth.  This script can also avoid dealing with latency in a remote shell's editor, however there could be cases where the editor is waiting on data from the remote path, auto-saving, etc.  I have personally not experienced any such issues, however.

### A few small warnings
First, this creates a temporary path in /tmp to mount the sshfs.  This should not be readable by other system users but since it is in /tmp it is worth mentioning.

Also, if your editor does git stuff, such as querying the current diffs, branches, etc, you might wind up with a git process doing stuff which might cause problems with unmounting the sshfs.  Saving and closing the file from the editor works fine in most cases.  Most modern fancy editors, such as Atom, Sublime, etc, may do this by default.  I have seen Sublime give some strange git-related errors sometimes after allowing the script to unmount sshfs.
