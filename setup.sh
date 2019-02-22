#!/bin/bash
set -e

DATACENTER="federation"
# shellcheck disable=SC1091
[ -f .environment ] && source ./.environment

force=false
if [ "$1" = "--force" ]; then
  force=true
  shift
fi

[ -d roles/mesos/tasks ] || ./after-git-clone.sh
./after-update.sh

./common/scripts/bootstrap.sh

count=$(git status --porcelain | wc -l)
if test "$count" -gt 0; then
  git status
  if $force; then
    echo "WARNING: Not all files have been committed in Git."
    echo "Will continue as --force is with you"
  else
    echo "Not all files have been committed in Git. Release aborted"
    exit 1
  fi
fi

ansible-playbook --ask-become-pass -i "envs/$DATACENTER/etc/ansible/" \
        -e play_dir="$(pwd)" \
        -e lib_roles_path="$(pwd)/roles" \
        -e datacenter="$DATACENTER" "$@" \
        install.yml

[ -f slack.json ] && (
  # shellcheck disable=SC2086
  : ${SLACK_USER_NAME:=$USER}

  # shellcheck disable=SC1091
  source ./common/lib/slack-helper.sh
  # shellcheck disable=SC1091
  source ./common/lib/ansible-to-human.sh "$@"
  sed "s/USER/$SLACK_USER_NAME/" slack.json | sed "s/COMPONENTS/$PLAYBOOK_COMPONENTS/" \
       | sed "s/HOSTS/$PLAYBOOK_HOSTS/" | post-to-slack
)
