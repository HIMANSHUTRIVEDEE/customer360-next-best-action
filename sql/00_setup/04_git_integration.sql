/*=============================================================================
  Git Integration Setup for Customer360 Next-Best-Action
  Repository: https://github.com/kishan080/customer360-next-best-action
  
  This script creates:
    1. Database & Schema for Git integration objects
    2. Secret storing GitHub PAT credentials
    3. API Integration for Git HTTPS access
    4. Git Repository clone linked to the GitHub repo
=============================================================================*/

-- Step 1: Create dedicated database and schema
CREATE DATABASE IF NOT EXISTS GIT_INTEGRATION_DB;
CREATE SCHEMA IF NOT EXISTS GIT_INTEGRATION_DB.GIT_REPOS;

-- Step 2: Create secret with GitHub Personal Access Token
CREATE OR REPLACE SECRET GIT_INTEGRATION_DB.GIT_REPOS.GITHUB_PAT_SECRET
  TYPE = password
  USERNAME = 'kishan080'
  PASSWORD = '<your_github_pat_token>';

-- Step 3: Create API Integration for GitHub
CREATE OR REPLACE API INTEGRATION GITHUB_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/kishan080')
  ALLOWED_AUTHENTICATION_SECRETS = (GIT_INTEGRATION_DB.GIT_REPOS.GITHUB_PAT_SECRET)
  ENABLED = TRUE;

-- Step 4: Create Git Repository clone
CREATE OR REPLACE GIT REPOSITORY GIT_INTEGRATION_DB.GIT_REPOS.CUSTOMER360_NEXT_BEST_ACTION
  API_INTEGRATION = GITHUB_API_INTEGRATION
  GIT_CREDENTIALS = GIT_INTEGRATION_DB.GIT_REPOS.GITHUB_PAT_SECRET
  ORIGIN = 'https://github.com/kishan080/customer360-next-best-action.git';

-- Step 5: Fetch latest changes from remote
ALTER GIT REPOSITORY GIT_INTEGRATION_DB.GIT_REPOS.CUSTOMER360_NEXT_BEST_ACTION FETCH;

-- Step 6: Verify - list branches
SHOW GIT BRANCHES IN GIT_INTEGRATION_DB.GIT_REPOS.CUSTOMER360_NEXT_BEST_ACTION;

-- Step 7: Verify - list files on main branch
LS @GIT_INTEGRATION_DB.GIT_REPOS.CUSTOMER360_NEXT_BEST_ACTION/branches/main/;
