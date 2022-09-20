from keyup._version import __version__ as version


__author__ = 'Blake Huber'
__version__ = version
__email__ = "blakeca00@gmail.com"


# ---  ancillary modules below line -------------------------------------------


try:

    from keyup import logd
    logger = logd.getLogger(__version__)

    # set pyaws log function to keyup global logger
    import pyaws
    pyaws.logger = logger

except Exception:
    pass
