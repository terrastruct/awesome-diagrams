#!/bin/sh
set -eu
if [ ! -e "$(dirname "$0")/ci/sub/.git" ]; then
  set -x
  git submodule update --init
  set +x
fi
. "$(dirname "$0")/ci/sub/lib.sh"
cd "$(dirname "$0")"

_ensure_referenced_images() {
  f="$1"
  dir=$(dirname "$f")
  imgs=$(yq eval '.images[]' "$f")

  if [ -z "$imgs" ]; then
    echoerr "No images found in $f."
    return 1
  fi

  exists=true
  for img in $imgs; do
    if [ ! -f "$dir/$img" ]; then
      echoerr "The image file '$img' does not exist in the directory '$dir'."
      exists=false
    fi
  done
  if [ $exists == false ]; then
    return 1
  fi
}

ensure_referenced_images() {
  sh_c XARGS_N=1 xargsd "'diagram\.\(yaml\|yml\)$'" | while IFS= read -r f; do
    _ensure_referenced_images "$f"
  done
}

fmt_yaml() {
  sh_c XARGS_N=1 xargsd "'\.\(yaml\|yml\)$'" yq eval -P -i
}

ensure_changed_files
job_parseflags "$@"
runjob fmt fmt_yaml &
runjob imgcheck ensure_referenced_images &
ci_waitjobs
