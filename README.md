# Brigadier

A Windows- and OS X-compatible Python script that fetches, from Apple's or your software update server, the Boot Camp ESD ("Electronic Software Distribution") for a specific model of Mac. It unpacks the multiple layers of archives within the flat package and if the script is run on Windows with the `--install` option, it also runs the 64-bit MSI installer. It currently _does not_ support installation on 32-bit Windows.

On Windows, the archives are unpacked using [7-Zip](http://www.7-zip.org) and [dmg2img](http://vu1tur.eu.org/tools), so these are downloaded and installed (and removed later) as needed. 7-Zip can convert .dmgs to ISOs as well, however I experienced inconsistent results across different currently-offered BootCampESD.pkgs, and haven't had any issues with dmg2img.

This was written for two reasons:

1. We'd like to maintain as few Windows system images as possible, but there are typically 3-5 BootCampESD packages available from Apple at any given time, targeting specific sets of models. It's possible to use the [Orca](http://support.microsoft.com/kb/255905) tool to edit the MSI's properties and disable the model check, but there are rarely cases where a single installer contains all drivers. Apple can already download the correct installer for a booted machine model in OS X using the Boot Camp Assistant, so there's no reason we can't do the same within Windows.
2. Sometimes we just want to download and extract a copy of the installer for a given model. The steps to do this manually are tedious, and there are many of them.

It was originally designed to be run as post-imaging step for Boot Camp deployments to Macs, but as it requires network connectivity, a network driver must be already available on the system. (See Caveats below)

## Windows requirements

You'll either need [Python for Windows](http://www.python.org/download/releases) (this was tested with the latest 2.7 release) in order to execute the script, or a tool like [PyInstaller](http://www.pyinstaller.org), which can compile the interpreter and script together into a single executable.

You can find a pre-compiled 32-bit binary (which will run on 64-bit Windows) of the most recent [release version](https://github.com/timsutton/brigadier/blob/master/VERSION) [here](https://dl.dropbox.com/u/429559/brigadier.zip) (sha1 189fa1b8f8267bb7bcb882e1becdc9e18c20f48a).

If you'd rather build it yourself using PyInstaller, install Python, PyInstaller and the appropriate version of [pywin32](http://sourceforge.net/projects/pywin32/files), then build a "single file deployment" with PyInstaller:

`%SystemRoot%\Python27\python \path\to\pyinstaller\pyinstaller.py -F \path\to\brigadier`

The resultant file should be in the `dist` folder created in the working directory.

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
  -l, --leave-files     Leave the files that were downloaded/extracted. Useful
                        only with the '--install' option on Windows.</code></pre>

You can also create a `brigadier.plist` XML plist file and place it in the same directory as the script. It currently supports one key: `CatalogURL`, a string that points to an internal SUS catalog URL that contains BootCampESD packages. See the example [in this repo](https://github.com/timsutton/brigadier/blob/master/plist-example/brigadier.plist).

## Running as a Sysprep FirstLogonCommand

It's common to perform the Boot Camp drivers during a post-imaging Sysprep phase, so that it's possible to deploy the same image to different models without taking into account the model and required Boot Camp package. Brigadier seems to behave in the context of a SysPrep [FirstLogonCommand](http://technet.microsoft.com/en-us/library/cc722150(v=ws.10).aspx).

There is one workaround performed by the script when running in this scenario, where the current working would normally be `\windows\system32`. In my tests on a 64-bit system, the MSI would halt trying to locate its installer components, due to the way Windows forks its `System32` folder into `SysWoW64` for 32-bit applications. When the script detects this working directory without a `--output-dir` option overriding it, it will set the output directory to the root of the system, ie. `%SystemRoot%\`.

By default, when `--install` is used, it will clean up its extracted files after installation, unless the `--leave-files` option is given, so unless you want to keep the files around you shouldn't need to clean up after it.

## Caveats

* It requires an internet connection, which therefore requires that a working network driver be available. The simplest way I've found to do this is to place the various network drivers from BootCampESDs inside a "BootCamp" (or similar) folder within `C:\Windows\INF`. This folder is the default search location for device drivers, and it should automatically detect and install drivers located here for all unknown hardware. You can also modify the `DevicePath` [registry key](http://technet.microsoft.com/en-us/library/cc731664(v=ws.10).aspx) to add a custom location, but using the existing `INF` folder means no other changes besides a file copy are required to update an existing image's drivers, so this can be done without actually restoring the image and booting it just to install a driver.
* It currently performs almost no error handling.
* After installation, it sets the `FirstTimeRun` registry key at `HKEY_CURRENT_USER\Software\Apple Inc.\Apple Keyboard Support` to disable the first-launch Boot Camp help popup, and there's currently no option to disable this behaviour. 
* Only tested on 64-bit Windows 7. It's worth mentioning that the December 2012 Boot Camp driver ESDs seem to be 64-bit only, so extra work would need to be done to support 32-bit Windows.
