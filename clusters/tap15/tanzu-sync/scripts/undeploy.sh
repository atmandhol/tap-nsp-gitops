#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail
#set -o xtrace

kapp delete -a tanzu-sync -y
