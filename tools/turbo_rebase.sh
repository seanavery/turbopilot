#!/usr/bin/env bash
set -e

if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  echo "Aborting ongoing rebase..."
  git rebase --abort
  git merge --abort
fi

echo "Fetching updates from origin (openpilot) and turbo (your fork)..."
git fetch origin master
git fetch turbo turbo

echo "Checking out origin/master temporarily to get submodule status..."
git checkout origin/master --detach

OPENPILOT_OPENDBC_COMMIT=$(git submodule status | grep "opendbc_repo" | awk '{print $1}')
if [ -z "$OPENPILOT_OPENDBC_COMMIT" ]; then
  echo "Failed to find the opendbc commit in origin/master. Exiting..."
  exit 1
fi
echo "Origin/master opendbc commit: ${OPENPILOT_OPENDBC_COMMIT}"

echo "Returning to turbo branch..."
git checkout turbo

# # Create merge on opendbc submodule turbo/turbo brannch with the commit hash from origin/master
echo "Creating merge commit on opendbc submodule turbo branch with commit hash ${OPENPILOT_OPENDBC_COMMIT}..."
cd opendbc_repo

# check if in the middle of a rebase or merge and exit if so
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  echo "Aborting ongoing rebase..."
  git rebase --abort
  git merge --abort
fi
git fetch origin master

# check if the commit hash is already in the opendbc_repo turbo branch
if git rev-parse --verify --quiet "turbo/${OPENPILOT_OPENDBC_COMMIT}"; then
  echo "The commit ${OPENPILOT_OPENDBC_COMMIT} is already in the opendbc_repo turbo branch. Exiting..."
  exit 0
fi

# Create a merge commit on the turbo branch
git merge --no-ff -m "Merge commit ${OPENPILOT_OPENDBC_COMMIT} from origin/master into turbo branch" "${OPENPILOT_OPENDBC_COMMIT}" || {
  echo "Merge conflict detected. Aborting merge..."
  git merge --abort
  exit 1
}

# # Stage the updated submodule pointer
# git add opendbc_repo
# # Commit the submodule pointer update (only if there is a change)
# if ! git diff-index --quiet HEAD; then
#   echo "Committing opendbc submodule update..."
#   git commit -m "Update opendbc submodule pointer to ${OPENPILOT_OPENDBC_COMMIT}"
# fi
# # Push changes to your turbo branch on your fork (turbo remote)
# echo "Pushing changes to turbo remote..."
# git push turbo turbo