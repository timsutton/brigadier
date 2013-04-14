## Modifying MSI properties

### Setting NOCHECK for non-Mac models

If you'd like to test a Boot Camp installation in a VM, a Boot Camp installer won't work out of the box, because one of its checks is to make sure the host is an appropriate Mac hardware model. However, this condition can be bypassed by setting a debug MSI property, `NOCHECK`, to 1. Components like graphics drivers still won't try to install, but at least the basic Boot Camp Services and several drivers will. It may be possible to force other components by setting other properties, but this should at least simulate a very basic install.

It's possible (with some difficulty) to obtain the Orca MSI-editing tool from Microsoft to modify the MSI database. However, these database modifications can also be saved to "transform" files and applied using other tools.

Included in this directory is a VBS script, `WiUseXfm.vbs`, copied from the [Windows Installer SDK scripting examples]("http://msdn.microsoft.com/en-ca/library/windows/desktop/aa372865(v=vs.85).aspx"). The `set_nocheck.mst` file is a pre-made transform that only modifies this `NOCHECK` property. This allows you to quickly modify the installer before calling `msiexec`. Here's how you could call this from within this folder:

`cscript WiUseXfm.vbs \path\to\Drivers\Apple\BootCamp.msi set_nocheck.mst`

Depending on its general usefulness for testing, this functionality will probably be rolled into brigadier as a command-line option.