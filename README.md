# ttp: TOTP Codes in the Shell

Generate two factor authentication codes that are compatible with
Google Authenticator (a.k.a. RFC6238 TOTP) from the shell.

## References

[RFC6238](https://tools.ietf.org/html/rfc6238)

## Installing

Just download and install
[`ttp`](https://raw.githubusercontent.com/dterei/ttp/master/ttp)
somewhere on your path (e.g., `$HOME/bin/ttp`).

`ttp` is a self-contained bash script; the TOTP code calculation
(base32 decoding and HMAC-SHA1) is implemented in bash itself, so no C
compiler or OpenSSL is needed.

### Required dependencies

| Dependency | Used for |
| --- | --- |
| bash | Running `ttp`. |
| [GnuPG](https://gnupg.org/) (`gpg`) | Encrypting the stored keys with a passphrase. |
| `mkdir` | Creating the key directory. |
| `date` | Reading the current time, on bash older than 5.0 only. |

`mkdir` and `date` come with every Linux distribution and macOS.

### Optional dependencies

`ttp` uses these if they are installed and works without them.

| Dependency | Used for | Without it |
| --- | --- | --- |
| `xclip` or `xsel` (Linux, X11) | Copying the code to the clipboard. | The code is printed. |
| `pbcopy` (built into macOS) | Copying the code to the clipboard. | The code is printed. |
| `zbarimg` (from [zbar](https://github.com/mchehab/zbar)) | `-c`: reading a QR code from the screen (X11 only). | You type in the key. |
| [`qrencode`](https://fukuchi.org/works/qrencode/) | `-v`: showing a key as a QR code. | `-v` doesn't work. |
| `display` (from [ImageMagick](https://imagemagick.org/)), `xv` or `xloadimage` | `-v`: showing the QR code in a window (X11 only). | The QR code is drawn in the terminal. |
| `gsettings` (GNOME) | Warning you if GNOME is set to cache your GPG passphrase indefinitely. | The check is skipped. |

### Upgrading from `ga`

`ttp` used to be called `ga`. It stores keys in `~/.config/ttp`, but
if that doesn't exist and `~/.config/ga` does, it keeps using
`~/.config/ga`. To switch over, run `mv ~/.config/ga ~/.config/ttp`.
Older versions of `ga` compiled a helper program into
`~/.config/ga/bin`; you can delete that directory.

## Using

* `ttp [-x]` _service_ - get token for _service_
* `ttp -[x]c` _service_ - record seed for new _service_
* `ttp -[x]v` _service_ - view qrcode for _service_
* `ttp -l` - list services setup

The `-x`, `-xc`, and `-xv` flags disable use of X11 even when
`$DISPLAY` is set, compared to no option, `-c`, and `-v`.

A key can be a base32 secret or an `otpauth://totp/` URI, such as the
ones in QR codes. URIs may set `digits` (1 to 10) and `period`; `ttp`
only supports the default SHA1 algorithm, and reports an error for any
other.

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
[github issue tracker](https://github.com/dterei/ttp/issues).

Master [git repository](https://github.com/dterei/ttp):

* `git clone https://github.com/dterei/ttp.git`

## Authors

David Terei.

## Acknowledgments

`ttp` is a fork of [`ga`](https://github.com/scslab/ga), written by
David Mazi&egrave;res.
