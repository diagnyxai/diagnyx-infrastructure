# GitHub Repository Rename Instructions

## Current State
- Local repository name: `diagnyx-infra`
- GitHub repository name: `diagnyx-infrastructure`

## To Rename GitHub Repository

### Option 1: GitHub Web Interface
1. Go to https://github.com/diagnyx/diagnyx-infrastructure
2. Click on "Settings" tab
3. Scroll down to "Repository name" section
4. Change name from `diagnyx-infrastructure` to `diagnyx-infra`
5. Click "Rename"

### Option 2: GitHub CLI (if installed)
```bash
gh repo rename diagnyx/diagnyx-infrastructure diagnyx-infra
```

### After Renaming
The Git remote URLs will automatically redirect, but you may want to update them:

```bash
cd /Users/santhosh/projects/diagnyx/workspace/repositories/diagnyx-infra
git remote set-url origin https://github.com/diagnyx/diagnyx-infra.git
```

## Note
- GitHub automatically creates redirects for the old repository name
- All existing clone URLs will continue to work
- Issues, pull requests, and other repository data are preserved
- The rename requires repository admin permissions

## Verification
After renaming, verify the change:
```bash
git remote -v
```

Should show:
```
origin	https://github.com/diagnyx/diagnyx-infra.git (fetch)
origin	https://github.com/diagnyx/diagnyx-infra.git (push)
```