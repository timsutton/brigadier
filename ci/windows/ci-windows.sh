#!/bin/bash

set -eux -o pipefail

PYTHON_VERSION=2.7.18

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"
python="/c/hostedtoolcache/windows/Python/${PYTHON_VERSION}/x64/python"
ls '/c/program files'

$python -V

# which python

pip install -r "${script_dir}/requirements.txt"
