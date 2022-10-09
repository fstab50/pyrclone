from pyrclone._version import __version__ as version


__author__ = 'Blake Huber'
__version__ = version
__email__ = "blakeca00@gmail.com"


# ---  ancillary modules below line -------------------------------------------


try:

    from pyrclone import logd

    # init logger object
    logger = logd.getLogger(__version__)

except Exception:
    pass
