#!/bin/bash

set -eux -o pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"

ls '/c/program files'

python -V

which python

pip install -r "${script_dir}/requirements.txt"
