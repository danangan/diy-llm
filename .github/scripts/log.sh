# Sourced by the other scripts. Colors only on a terminal or in CI (GitHub Actions renders them).
if [[ -t 1 || -n "${CI:-}" ]] && [[ -z "${NO_COLOR:-}" ]]; then
  _blue=$'\e[1;34m' _green=$'\e[1;32m' _red=$'\e[1;31m' _reset=$'\e[0m'
else
  _blue='' _green='' _red='' _reset=''
fi

log() { echo "${_blue}===>${_reset} $*"; }
ok() { echo "${_green}===>${_reset} $*"; }
die() { echo "${_red}===>${_reset} $*" >&2; exit 1; }
