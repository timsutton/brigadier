#!/bin/bash

set -eux -o pipefail

PYTHON_VERSION=2.7.18

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"
python="/c/hostedtoolcache/windows/Python/${PYTHON_VERSION}/x64/python"

export PYTHONPATH="${python}"
$python -V
$python -m pip install -r "${script_dir}/requirements.txt"

# pip-installed exes will be installed here, so we'll put those at the front
# of the PATH
PATH="/c/hostedtoolcache/windows/Python/${PYTHON_VERSION}/x64/Scripts:$PATH"

pyinstaller \
    --onefile \
    brigadier
