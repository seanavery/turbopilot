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
git submodule update --init --recursive

OPENPILOT_OPENDBC_COMMIT=$(git submodule status | grep "opendbc_repo" | awk '{print $1}'  | sed 's/^+//')
if [ -z "$OPENPILOT_OPENDBC_COMMIT" ]; then
  echo "Failed to find the opendbc commit in origin/master. Exiting..."
  exit 1
fi
echo "Origin/master opendbc commit: ${OPENPILOT_OPENDBC_COMMIT}"

echo "Returning to turbo branch..."
git checkout turbo

# Create merge on opendbc submodule turbo/turbo brannch with the commit hash from origin/master
echo "Creating merge commit on opendbc submodule turbo branch with commit hash ${OPENPILOT_OPENDBC_COMMIT}"
cd opendbc_repo
git checkout turbo

# Initialize the flag
SUBMODULE_UP_TO_DATE=false

# check if the commit hash is already in the opendbc_repo turbo branch
if git merge-base --is-ancestor "${OPENPILOT_OPENDBC_COMMIT}" turbo; then
  echo "The commit ${OPENPILOT_OPENDBC_COMMIT} is already in the opendbc_repo turbo branch."
  SUBMODULE_UP_TO_DATE=true
else
  echo "New commit detected for opendbc_repo. Creating a PR..."

  # Create a new branch for the pull request
  PR_BRANCH="merge-origin-master-${OPENPILOT_OPENDBC_COMMIT}-$(date +%Y%m%d-%H%M%S)"
  echo "Creating a new branch: ${PR_BRANCH}"
  git checkout -b "${PR_BRANCH}"

  # Attempt to create a merge commit
  echo "Creating a merge commit for commit ${OPENPILOT_OPENDBC_COMMIT} from origin/master into turbo branch..."
  if git merge --no-ff -m "Merge commit ${OPENPILOT_OPENDBC_COMMIT} from origin/master into turbo branch" "${OPENPILOT_OPENDBC_COMMIT}"; then
    echo "Merge successful."
  else
    echo "Merge conflict detected. Committing conflict markers..."
    git add opendbc_repo
    git commit -m "WIP: Resolve merge conflicts for ${OPENPILOT_OPENDBC_COMMIT}" --no-verify
  fi

  echo "Pushing the new branch to turbo remote..."
  git push turbo "${PR_BRANCH}"

  if git diff --quiet turbo; then
    echo "No changes detected between ${PR_BRANCH} and turbo. Exiting..."
    exit 0
  fi

  sleep 2

  if command -v gh &> /dev/null; then
    echo "Creating pull request for opendbc submodule..."
    gh pr create \
      --repo "seanavery/turbodbc" \
      --title "Merge origin/master into turbo branch" \
      --body "This PR merges origin/master into turbo and resolves conflicts for commit ${OPENPILOT_OPENDBC_COMMIT}." \
      --base turbo \
      --head "${PR_BRANCH}"
  else
    echo "GitHub CLI not found. Please create a pull request manually from the branch ${PR_BRANCH}."
  fi
fi

# If submodule is up to date, or after submodule PR is created, optionally merge openpilot
# Return to openpilot directory
cd ..

if [ "$SUBMODULE_UP_TO_DATE" = "true" ]; then
  echo "No changes needed for opendbc. Attempting merge for openpilot..."

  # (Fetch and merge the openpilot parent repo)
  git fetch origin master

  PARENT_PR_BRANCH="merge-parent-origin-master-$(date +%Y%m%d-%H%M%S)"
  echo "Creating a new branch for openpilot: ${PARENT_PR_BRANCH}"
  git checkout turbo
  git checkout -b "${PARENT_PR_BRANCH}"

  git add opendbc_repo
  if ! git diff --cached --exit-code; then
    git commit -m "Update opendbc submodule pointer to ${OPENPILOT_OPENDBC_COMMIT}" --no-verify
  else
    echo "Submodule pointer already matches. No new commit needed."
  fi

  echo "Merging origin/master into local turbo branch (openpilot parent)..."
  if git merge --no-ff origin/master -m "Merge origin/master into turbo branch"; then
    echo "Merge successful. Pushing changes to turbo remote..."
  else
    echo "Merge conflict detected in openpilot. Committing conflict markers..."
    git add .
    git diff --cached --name-status
    git commit -m "WIP: Resolve conflicts in openpilot master merge" --no-verify
  fi

  GIT_LFS_SKIP_PUSH=1 git push turbo "${PARENT_PR_BRANCH}"

  if command -v gh &> /dev/null; then
    echo "Creating pull request for openpilot parent repo..."
    gh pr create \
      --repo "seanavery/turbopilot" \
      --title "Merge origin/master into turbo" \
      --body "Merging openpilot master into turbo branch after submodule checks." \
      --base turbo \
      --head "${PARENT_PR_BRANCH}"
  else
    echo "GitHub CLI not found. Please create a pull request manually from the branch ${PARENT_PR_BRANCH}."
  fi
fi
echo "Done!"
