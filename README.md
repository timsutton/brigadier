# Brigadier

A Windows- and OS X-compatible Python script that fetches, from Apple's or your software update server, the Boot Camp ESD ("Electronic Software Distribution") for a specific model of Mac. It unpacks the multiple layers of archives within the flat package and if the script is run on Windows with the `--install` option, it also runs the 64-bit MSI installer.

On Windows, the archives are unpacked using [7-Zip](http://www.7-zip.org), and the 7-Zip MSI is downloaded and installed, and removed later if Brigadier installed it. This tool used to use [dmg2img](http://vu1tur.eu.org/tools/) to perform the extraction of files from Apple's `WindowsSupport.dmg` file, but more recent versions of 7-Zip have included more completely support for DMGs, so dmg2img seems to be no longer needed.

This was written for two reasons:

1. We'd like to maintain as few Windows system images as possible, but there are typically 3-5 BootCampESD packages available from Apple at any given time, targeting specific sets of models. It's possible to use the [Orca](http://support.microsoft.com/kb/255905) tool to edit the MSI's properties and disable the model check, but there are rarely cases where a single installer contains all drivers. Apple can already download the correct installer for a booted machine model in OS X using the Boot Camp Assistant, so there's no reason we can't do the same within Windows.
2. Sometimes we just want to download and extract a copy of the installer for a given model. The steps to do this manually are tedious, and there are many of them. As of the spring of 2013, Apple has made a number of Boot Camp installer packages available on their support downloads page, but they are still a split across many different different sets of models and it is still inconvenient to ensure you have the correct package.

It was originally designed to be run as post-imaging step for Boot Camp deployments to Macs, but as it requires network connectivity, a network driver must be already available on the system. (See Caveats below)

## Important (!) note on support for Brigadier

Brigadier has produced less-than-great results with some combinations of driver packages and hardware models in recent versions of Boot Camp 5, and now with Boot Camp 6. Some people have confirmed issues with Boot Camp 6 and Windows 7 in general, so these may not be entirely Brigadier's fault. Some examination of the Boot Camp `setup.exe` indicates to me that this executable performs several tasks and sets up some environment for the eventual execution of `BootCamp.msi`, which we're not always able to get with Brigadier's simple invocation of `msiexec` to install the MSI directly.

I'm far from knowledgable enough about Windows internals to understand how to be able to perform a fully-automated version of whatever setup.exe actually does (besides eventually run `msiexec /i /qr` on the MSI). For example, [this PR](https://github.com/timsutton/brigadier/pull/14) suggests that better results can be achieved by using different "quiet" options to `msiexec`, but a disassembly of `setup.exe` shows that it is actually executing `/qr`, as does the code in the current master branch. This kind of question is one I don't feel I have enough knowledge to attempt an answer.

There have been strange issues I've experienced a couple of years ago as well. For example, a single driver installer (Intel chipset-related) that pops up a series of WinRAR SFX errors due to it attempting to sequentially execute all of the driver's localization files (which aren't even executable). Simply clicking through these dialogs eventually causes the installation to continue, but until that happens the process is blocked. This error doesn't happen when a user manually runs `setup.exe`, but why I do not understand.

While I maintain some hope to be able to resolve these issues, my environment's use case for dual-boot labs is shrinking and so it's difficult to justify the time required to spend further researching these issues. If anyone who is knowledgeable about reversing `setup.exe`-like installer wrappers and MSI installers, and Windows systems administration in general, is interested in tackling the currently-somewhat-broken support for silent installs of Boot Camp drivers in this tool, I'd love some help! There are several installer properties in `BootCamp.msi` that may be of some help with this issue as well.

## Usage

Run brigadier with no options to download and unpack the ESD that applies to this model, to the current working directory. On OS X, the ESD is kept in a .dmg format for easy burning to a disc; on Windows, the driver files are extracted.

Run it with the `--model` option to specify an alternate model, in the form `MacPro3,1`, etc.

Run it with the `--install` option to both download and install, deleting the drivers after installation. This obviously works only on Windows. This option was made for doing automated installations of the Boot Camp drivers.

Place a `brigadier.plist` file in the same folder as the script to override the .sucatalog URL to point to an internal Software Update Server catalog (details below).

Additional options shown below.

### Usage on newer Macs

To use it on newer mac machines that come with **Python 3**, use the `python3` branch.

## Getting it

You can find a pre-compiled binary for Windows in the [releases](https://github.com/timsutton/brigadier/releases) area. This can be useful if you don't already have Python installed on Windows. This was built using [PyInstaller](http://www.pyinstaller.org). More details on building it yourself [below](#runningbuilding-from-source-on-windows).

It can also be run directly from a Git checkout on either OS X or Windows.

## Configuration

Besides a few command-line options:

<pre><code>Usage: brigadier [options]

Options:
  -h, --help            show this help message and exit
  -m MODEL, --model=MODEL
                        System model identifier to use (otherwise this
                        machine's model is used).
  -i, --install         After the installer is downloaded, perform the install
                        automatically. Can be used on Windows only.
  -o OUTPUT_DIR, --output-dir=OUTPUT_DIR
                        Base path where the installer files will be extracted
                        into a folder named after the product, ie.
                        'BootCamp-041-1234'. Uses the current directory if
                        this option is omitted.
  -k, --keep-files      Keep the files that were downloaded/extracted. Useful
                        only with the '--install' option on Windows.</code></pre>

You can also create a `brigadier.plist` XML plist file and place it in the same directory as the script. It currently supports one key: `CatalogURL`, a string that points to an internal SUS catalog URL that contains BootCampESD packages. See the example [in this repo](https://github.com/timsutton/brigadier/blob/master/plist-example/brigadier.plist).

## Running as a Sysprep FirstLogonCommand

It's common to perform the Boot Camp drivers during a post-imaging Sysprep phase, so that it's possible to deploy the same image to different models without taking into account the model and required Boot Camp package. Brigadier seems to behave in the context of a SysPrep <a href="http://technet.microsoft.com/en-us/library/cc722150(v=ws.10).aspx">FirstLogonCommand</a>.

There is one workaround performed by the script when running in this scenario, where the current working would normally be `\windows\system32`. In my tests on a 64-bit system, the MSI would halt trying to locate its installer components, due to the way Windows forks its `System32` folder into `SysWoW64` for 32-bit applications. When the script detects this working directory without a `--output-dir` option overriding it, it will set the output directory to the root of the system, ie. `%SystemRoot%\`.

By default, when `--install` is used, it will clean up its extracted files after installation, unless the `--keep-files` option is given, so unless you want to keep the files around you shouldn't need to clean up after it.

## Running/building from source on Windows

If you'd rather run it as a standard Python script, you'll need [Python for Windows](http://www.python.org/download/releases) (this was tested with the latest 2.7 release) in order to execute the script.

If you'd rather build it yourself, you can use the included build script. It requires [Python](http://www.python.org/download/releases) and the matching version of [pywin32](http://sourceforge.net/projects/pywin32/files). It handles downloading PyInstaller for you. Simply run it with no arguments, and it will build a zip file in the current working directory:

`c:\python27\python build_windows_exe.py`

## Unpack details on Windows

On OS X, we have the native hdiutil and pkgutil commands to do the work of unpacking the driver files. On Windows, we:

1. Check if 7-Zip is already installed - if not, we download and install it
2. Extract the BootCampESD.pkg xar archive with 7-Zip
3. Extract the Payload archive with 7-Zip, once to decompress gzip and again to unpack the cpio archive
4. Use 7-Zip to extract the driver files from the `WindowsSupport.dmg` file within the pkg
5. Uninstall 7-Zip if we installed it

## Caveats

* It requires a network connection, which therefore requires that a working network driver be available. The simplest way I've found to do this is to place the various network drivers from BootCampESDs inside a "BootCamp" (or similar) folder within `C:\Windows\INF` on a sysprepped image. This folder is the default search location for device drivers, and it should automatically detect and install drivers located here for all unknown hardware. You can also modify the `DevicePath` <a href="http://technet.microsoft.com/en-us/library/cc731664(v=ws.10).aspx">registry key</a> to add a custom location, but using the existing `INF` folder means no other changes besides a file copy are required to update an existing image's drivers, so this can be done without actually restoring the image and booting it just to install a driver. Offline driver servicing using Windows and DISM is easy for WIM images, but most admins are likely not deploying WIM images to Macs, but rather using tools that wrap ntfsprogs.
* It currently performs almost no error handling.
* The 7-Zip downloads from a public URLs which is hardcoded in the script. Soon the `brigadier.plist` will support overriding these URLs with your own copies stored on a private webserver.
* After installation, it sets the `FirstTimeRun` registry key at `HKEY_CURRENT_USER\Software\Apple Inc.\Apple Keyboard Support` to disable the first-launch Boot Camp help popup, and there's currently no option to disable this behaviour.
* Only supports installations on 64-bit Windows. It's worth mentioning that the December 2012 Boot Camp driver ESDs seem to be 64-bit only, so extra work would need to be done to support 32-bit Windows. If 32-bit Windows support is important to you, there is an [issue](https://github.com/timsutton/brigadier/issues/2) created to track it.
