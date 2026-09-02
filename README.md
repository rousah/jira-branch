# jira-branch

Create a git branch from a Jira ticket URL (or key), named:

```
<type>/<TICKET-KEY>-<summary-slug>
```

e.g. `${JIRA_BRANCH_BASE_URL}/browse/NPOST-23163` -> `feat/NPOST-23163-some-ticket-summary`

## Setup

1. Install plugin in your oh-my-zsh plugin directory (default `~/oh-my-zsh/custom/plugins`)
2. Enable the plugin in `~/.zshrc`:
   ```zsh
   plugins=(... jira-branch)
   ```
3. Create an Atlassian API token: https://id.atlassian.com/manage-profile/security/api-tokens
4. Export credentials (e.g. in `~/.zshrc` or a private env file):
   ```zsh
   export JIRA_EMAIL="you@example.com"
   export JIRA_API_TOKEN="your-api-token"
   ```

## Usage

```zsh
jira-branch ${JIRA_BRANCH_BASE_URL}/browse/NPOST-23163
jira-branch NPOST-23163
jira-branch NPOST-23163 chore
```
or 
```zsh
jb ${JIRA_BRANCH_BASE_URL}/browse/NPOST-23163
jb NPOST-23163
jb NPOST-23163 chore
```

This fetches the ticket's issue type and summary, builds the branch name, and
checks it out (creating it if needed). Pass an optional second argument to
override the mapped prefix; the override is normalized to lowercase kebab-case.
A trailing `-web` in the summary is omitted from the branch name.

## Type mapping

| Jira issue type | Branch prefix |
|---|---|
| Bug | fix |
| Story | feat |
| Clone-story | feat |
| Task / Sub-task | feat |
| Spike | feat |
| other | lowercased issue type with spaces and punctuation replaced by `-` |

## Optional

- `JIRA_BRANCH_BASE_URL` — override the Jira site base URL when passing a bare
  ticket key.
- Install `jq` for more robust JSON parsing (falls back to `sed` if absent).
