#!/usr/bin/env python3


import os
import sys
import subprocess
import argparse
from shutil import rmtree, which
from libtools import exit_codes, logd, stdout_message
from libtools import Colors, ColorMap
from rcloneit import logger

# globals
cm = ColorMap()


PKG_ACCENT = Colors.ORANGE
PARAM_ACCENT = Colors.WHITE
bdwt = cm.bd + cm.bwt


write_dir = '/home/Downloads/gdrive'
__version__ = '0.3'

def clear_tempspace(directory):
    """
        Clear contents of fs directory provided as parameter

    Returns:
        TYPE:  Boolean
    """
    try:
        for x in os.listdir(directory):
            if os.path.isdir(os.path.join(directory, x)):
                print('Removing directory %s' % x)
                rmtree(os.path.join(directory, x))
            elif os.path.isfile(os.path.join(directory, x)):
                print('Removing file %s' % x)
                os.remove(os.path.join(directory, x))
    except FileNotFoundError as e:
        stdout_message('%s Directory not found.  Error code %s' % (directory, exit_codes['EX_DIR']['Code']), 'warn')
        return False
    except Exception:
        stdout_message('Unknown error ocurred.  Error code %s' % sys.exit_codes['EX_MISC']['Code'], 'warn')
        return False
    return True


def is_installed(program, silent=True):
    """
        Check to see if rclone is installed and executable

    Returns:
        TYPE:  boolean, Success || Failure
    """
    cmd = 'which rclone 2>/dev/null | grep rclone'
    if which(program):
        if silent is False:
            stdout_message(f'Program {program} is installed')
        return True
    if silent is False:
        stdout_message(f'Program {program} is not installed or is not in PATH. Quitting.', prefix='warn')
    return False


def help_menu():
    """Displays user command-line parameters"""
    print('Help menu here (TBD)')
    sys.stdout.write('\n')
    return True


def list_data_sources():
    """
        Get rclone data sources available on local machine

    Returns:
        TYPE: list
    """
    cmd = 'rclone listremotes'
    return subprocess.getoutput(cmd).split('\n')


def options(parser, help_menu=False):
    """
        Parse cli parameter options

    Returns:
        TYPE: argparse object, parser argument set
    """
    parser.add_argument("-c", "--clean", dest='clean', action='store_true', default="", required=False, help="type (default: %(default)s)")
    parser.add_argument("-d", "--download", dest='download', action='store_true', default="", required=False, help="type (default: %(default)s)")
    parser.add_argument("-l", "--list", dest='list', action='store_true', required=False, help="type (default: %(default)s)")
    parser.add_argument("-r", "--remote", dest='remote', action='store_true', default="", required=False, help="type (default: %(default)s)")
    parser.add_argument("-fs", "--localfs", dest='localfs', default="", required=False, help="type (default: %(default)s)")
    parser.add_argument("-h", "--help", dest='help', action='store_true', required=False)
    parser.add_argument("-V", "--version", dest='version', action='store_true', required=False)
    return parser.parse_args()


def init():
    """Caller function; initializes all functionality"""
    try:

        #  argument paring
        parser = argparse.ArgumentParser(add_help=False)

    except KeyError:
        print('\nProblem with invalid parameters.\n')

    try:

        args = options(parser)

    except Exception as e:
        help_menu()
        stdout_message(str(e), 'ERROR')
        sys.exit(exit_codes['EX_OK']['Code'])


    if len(sys.argv) == 1:
        # display help menu as default output
        help_menu()
        sys.exit(exit_codes['EX_OK']['Code'])

    elif args.clean:
        # clean landing zone of any files or directories
        if args.localfs:
            write_dir = args.localfs
            clear_tempspace(write_dir)
        else:
            stdout_message('You must also enter a local filesystem directory to clean (--localfs)', prefix='warn')

    elif args.help:
        help_menu()
        sys.exit(exit_codes['EX_OK']['Code'])

    elif args.list:
        # check if rclone installed and accessible
        if is_installed('rclone'):
            # installed, continue
            remotes = list_data_sources()
            n = 1
            stdout_message('Found the following rclone remote endpoints found on this machine:')
            for i in remotes:
                print('\t'.expandtabs(16) + f'{n}:   ' + str(i))
                n += 1
            print('\n', end='')
            sys.exit(exit_codes['EX_OK']['Code'])
        sys.exit(1)

    elif args.version:
        print(f'\nrclone version {__version__} \n')
        sys.exit(exit_codes['EX_OK']['Code'])

    failure = """ : Check of runtime parameters failed for unknown reason.
    Please ensure local awscli is configured. Then run keyconfig to
    configure keyup runtime parameters.   Exiting. Code: """
    #print(failure)
    logger.warning(failure + 'Exit. Code: %s' % sys.exit(exit_codes['EX_MISC']['Code']))

# run
init()


sys.exit(exit_codes['EX_OK']['Code'])
