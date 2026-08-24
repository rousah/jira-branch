# jira-branch: create a git branch from a Jira ticket URL
#
# Usage:
#   jira-branch ${JIRA_BRANCH_BASE_URL}/browse/NPOST-23163
#   jira-branch NPOST-23163
#
# Produces a branch like: feature/NPOST-23163-some-ticket-summary
# and checks it out (creating it if it doesn't already exist).
#
# Requires:
#   JIRA_EMAIL       - your Atlassian account email
#   JIRA_API_TOKEN   - an API token (https://id.atlassian.com/manage-profile/security/api-tokens)
#
# Optional:
#   JIRA_BRANCH_BASE_URL - override the Jira site base URL (default derived from the ticket URL, if only a ticket key is given)

alias jb='jira-branch'

_jira_branch_type_prefix() {
  local issue_type="$1"
  local lower
  lower=$(echo "$issue_type" | tr '[:upper:]' '[:lower:]')

  case "$lower" in
    bug) echo "fix" ;;
    story|clone-story|task|sub-task|subtask|spike) echo "feat" ;;
    *) echo "$lower" | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//' ;;
  esac
}

_jira_branch_slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '-' \
    | sed 's/^-*//;s/-*$//'
}

jira-branch() {
  emulate -L zsh
  setopt local_options pipefail

  if [[ -z "$1" ]]; then
    echo "Usage: jira-branch <jira-ticket-url-or-key>" >&2
    return 1
  fi

  if [[ -z "$JIRA_EMAIL" || -z "$JIRA_API_TOKEN" ]]; then
    echo "jira-branch: JIRA_EMAIL and JIRA_API_TOKEN must be set." >&2
    echo "Create an API token at https://id.atlassian.com/manage-profile/security/api-tokens" >&2
    return 1
  fi

  local input="$1"
  local base_url ticket_key

  if [[ "$input" =~ ^https?://([^/]+)/browse/([A-Za-z0-9]+-[0-9]+) ]]; then
    base_url="https://${match[1]}"
    ticket_key="${match[2]}"
  elif [[ "$input" =~ ^[A-Za-z0-9]+-[0-9]+$ ]]; then
    ticket_key="$input"
    base_url="${JIRA_BRANCH_BASE_URL}"
  else
    echo "jira-branch: could not parse a Jira ticket URL or key from '$input'" >&2
    return 1
  fi

  if [[ -n "$JIRA_BRANCH_BASE_URL" ]]; then
    base_url="$JIRA_BRANCH_BASE_URL"
  fi

  ticket_key=$(echo "$ticket_key" | tr '[:lower:]' '[:upper:]')

  local api_url="${base_url}/rest/api/3/issue/${ticket_key}?fields=summary,issuetype"
  local response http_code body

  response=$(curl -sS -w '\n%{http_code}' \
    -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    -H "Accept: application/json" \
    "$api_url")

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    echo "jira-branch: failed to fetch ${ticket_key} (HTTP ${http_code})" >&2
    echo "$body" >&2
    return 1
  fi

  local summary issue_type
  if command -v jq >/dev/null 2>&1; then
    summary=$(echo "$body" | jq -r '.fields.summary')
    issue_type=$(echo "$body" | jq -r '.fields.issuetype.name')
  else
    summary=$(echo "$body" | sed -n 's/.*"summary":"\([^"]*\)".*/\1/p' | head -n1)
    issue_type=$(echo "$body" | sed -n 's/.*"issuetype":{[^}]*"name":"\([^"]*\)".*/\1/p' | head -n1)
  fi

  if [[ -z "$summary" || -z "$issue_type" ]]; then
    echo "jira-branch: could not parse summary/issue type from Jira response" >&2
    return 1
  fi

  local prefix slug branch_name
  prefix=$(_jira_branch_type_prefix "$issue_type")
  slug=$(_jira_branch_slugify "$summary")
  branch_name="${prefix}/${ticket_key}-${slug}"

  echo "Ticket:  ${ticket_key} (${issue_type})"
  echo "Summary: ${summary}"
  echo "Branch:  ${branch_name}"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "jira-branch: not inside a git repository, skipping checkout." >&2
    return 1
  fi

  if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name"
  fi
}
