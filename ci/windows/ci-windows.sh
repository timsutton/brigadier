#!/bin/bash

set -eux -o pipefail

PYTHON_VERSION=2.7.18

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"
python="/c/hostedtoolcache/windows/Python/${PYTHON_VERSION}/x64/python"
ls '/c/program files'
export PYTHONPATH="${python}"
$python -V

$python -m pip install -r "${script_dir}/requirements.txt"

pyinstaller \
    --onefile \
    brigadier
