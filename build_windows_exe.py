# build_windows_exe.py
#
# Builds a Windows exe of brigadier using PyInstaller. PyInstaller
# will be downloaded to the cwd and its archive kept for later use.
#
# Requires:
# - Python 2.7 for Windows (http://www.python.org/getit)
# - pywin32 (http://sourceforge.net/projects/pywin32)

import urllib
import os
from zipfile import ZipFile, BadZipfile
import subprocess
import shutil
import hashlib

PYINSTALLER_URL = 'https://pypi.python.org/packages/source/P/PyInstaller/PyInstaller-2.1.zip'
PYINST_ZIPFILE = os.path.join(os.getcwd(), 'pyinstaller.zip')
NAME = 'brigadier'

with open('VERSION', 'r') as fd:
    version = fd.read().strip()
name_versioned = NAME + '-' + version
exe_name = NAME + '.exe'
pack_dir = os.path.join(os.getcwd(), name_versioned)
build_dir = os.path.join(os.getcwd(), 'build')

need_pyinstaller = False
if os.path.exists(PYINST_ZIPFILE):
    print "PyInstaller zipfile found."
    try:
        ZipFile(PYINST_ZIPFILE)
    except BadZipfile:
        print "Zipfile is corrupt."
        need_pyinstaller = True
else:
    need_pyinstaller = True

if need_pyinstaller:
    print "Downloading PyInstaller..."
    urllib.urlretrieve(PYINSTALLER_URL, filename=PYINST_ZIPFILE)

dlzip = ZipFile(PYINST_ZIPFILE)
pyinst_root = dlzip.namelist()[0].split("/")[0]
dlzip.extractall()

print "Building version %s..." % version
build_cmd = [os.path.join(os.environ["SYSTEMDRIVE"] + "\\", 'Python27', 'python.exe'),
             os.path.join(os.getcwd(), pyinst_root, 'pyinstaller.py'),
             '-F',
             '--distpath', pack_dir,
             '--name', NAME,
             'brigadier']
subprocess.call(build_cmd)

print "Compressing to zip file..."
zipfile_name = name_versioned + '.zip'
packzip = ZipFile(zipfile_name, 'w')
packzip.write(os.path.basename(pack_dir))
packzip.write(os.path.join(os.path.basename(pack_dir), exe_name))
packzip.close()
with open(zipfile_name, 'r') as zipfd:
    sha1 = hashlib.sha1(zipfd.read()).hexdigest()

print "Cleaning up..."
for dirs in [pack_dir, build_dir, pyinst_root]:
    shutil.rmtree(dirs)
for f in os.listdir(os.getcwd()):
    if f.startswith('logdict'):
        os.remove(f)

print "Built and archived to %s." % zipfile_name
print "SHA1: %s" % sha1
