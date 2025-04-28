#!/usr/bin/env bash
set -e

if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  echo "Aborting ongoing rebase..."
  git rebase --abot
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

# Attempt to create a merge commit
echo "Creating a merge commit for commit ${OPENPILOT_OPENDBC_COMMIT} from origin/master into turbo branch..."
if git merge --no-ff -m "Merge commit ${OPENPILOT_OPENDBC_COMMIT} from origin/master into turbo branch" "${OPENPILOT_OPENDBC_COMMIT}"; then
  # If merge succeeds, push changes
  echo "Merge successful. Pushing changes to turbo remote..."
  git push turbo turbo
else
  # If merge conflicts occur, abort the merge and create a pull request
  echo "Merge conflict detected. Aborting merge and creating a pull request..."
  git merge --abort

  # Create a new branch for the pull request
  PR_BRANCH="merge-origin-master-${OPENPILOT_OPENDBC_COMMIT}"
  git checkout -b "${PR_BRANCH}"

  # Retry the merge on the new branch
  git merge --no-ff -m "Merge commit ${OPENPILOT_OPENDBC_COMMIT} from origin/master into turbo branch" "${OPENPILOT_OPENDBC_COMMIT}" || {
    echo "Merge conflict detected on PR branch. Committing conflict markers..."
    git add -A
    git commit -m "WIP: Resolve merge conflicts for ${OPENPILOT_OPENDBC_COMMIT}"
  }

  # Push the new branch to the turbo remote
  git push turbo "${PR_BRANCH}"

  # Create a pull request using GitHub CLI
  # if command -v gh &> /dev/null; then
  #   echo "Creating pull request..."
  #   gh pr create \
  #     --title "Merge origin/master into turbo branch" \
  #     --body "This PR merges origin/master into turbo and resolves conflicts for commit ${OPENPILOT_OPENDBC_COMMIT}." \
  #     --base turbo \
  #     --head "${PR_BRANCH}"
  # else
  #   echo "GitHub CLI not installed. Please create the pull request manually."
  # fi
fi
