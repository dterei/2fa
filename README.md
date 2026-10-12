# ttp: TOTP Codes in the Shell

Generate two factor authentication codes that are compatible with
Google Authenticator (a.k.a. RFC6238 TOTP) from the shell.

## References

[RFC6238](https://tools.ietf.org/html/rfc6238)

## Installing

Just download and install
[`ttp`](https://raw.githubusercontent.com/dterei/2fa/master/ttp)
somewhere on your path (e.g., `$HOME/bin/ttp`).

Requirements:

* bash
* gnupg

`ttp` is a self-contained bash script; the TOTP code calculation
(base32 decoding and HMAC-SHA1) is implemented in bash itself, so no C
compiler or OpenSSL is needed.

`ttp` used to be called `ga`. It stores keys in `~/.config/ttp`, but
if that doesn't exist and `~/.config/ga` does, it keeps using
`~/.config/ga`. To switch over, run `mv ~/.config/ga ~/.config/ttp`.
Older versions of `ga` compiled a helper program into
`~/.config/ga/bin`; you can delete that directory.

Optional dependencies:

* xclip - to send login codes to the X clipboard instead of stdout
* zbar - to parse QR codes from screen with -c option
* qrencode, imagemagick - to display QR codes with -v option

## Using

* `ttp [-x]` _service_ - get token for _service_
* `ttp -[x]c` _service_ - record seed for new _service_
* `ttp -[x]v` _service_ - view qrcode for _service_
* `ttp -l` - list services setup

The `-x`, `-xc`, and `-xv` flags disable use of X11 even when
`$DISPLAY` is set, compared to no option, `-c`, and `-v`.

## OS X and GPG Tools

Mac OS X users may be using the [GPG Tools](https://gpgtools.org/)
distribution. For some strange reason, this package doesn't detect
when you are running in a terminal session without a display (e.g.,
SSH), so by default, it always launches a GUI for key entry. Which
makes `ttp` impossible to use over SSH on OS X.

To fix this, you'll want to tell it to uses a curses display for
passpharse entry:

    export PINENTRY_USER_DATA="USE_CURSES=1"

A good way to decide when to export this variable is by detecting it
`SSH_CONNECTION` is a non-empty string.

## Get involved!

We are happy to receive bug reports, fixes, documentation enhancements,
and other improvements.

Please report bugs via the
[github issue tracker](https://github.com/dterei/2fa/issues).

Master [git repository](https://github.com/dterei/2fa):

* `git clone https://github.com/dterei/2fa.git`

## Authors

David Terei.
