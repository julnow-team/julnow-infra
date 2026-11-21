# JulNow Dev Setup

## 1. Tools

- Git
- PowerShell 7 (`winget install Microsoft.PowerShell`)
- Docker Desktop
- VS Code
- JDK 21 (Temurin)
- IntelliJ IDEA
- Flutter SDK + Android Studio

## 2. Folder

Put every repo under the same folder:

```
D:\julnow\
├── julnow-infra
├── julnow-gateway
├── julnow-auth-service
├── julnow-listing-service
├── julnow-booking-service
├── julnow-admin-web
└── julnow-mobile
```

## 3. Clone

```powershell
mkdir D:\julnow
cd D:\julnow
git clone https://github.com/julnow-team/julnow-infra.git
```

## 4. Start the database

```powershell
cd D:\julnow\julnow-infra
docker compose up -d postgres
docker compose ps
```

STATUS must show `(healthy)`.

Check the databases:

```powershell
docker compose exec postgres psql -U julnow -d postgres -c "\l"
```

You should see `julnow_auth`, `julnow_listing`, `julnow_booking`.

## 5. Connection info (local only)

| Key      | Value               |
|----------|---------------------|
| Host     | localhost           |
| Port     | 5432                |
| User     | julnow              |
| Password | julnow_dev_password |

## 6. Daily commands

| Task                    | Command                          |
|-------------------------|----------------------------------|
| Start DB                | `docker compose up -d postgres`  |
| Stop DB (keep data)     | `docker compose stop`            |
| See logs                | `docker compose logs -f postgres`|
| Reset DB (delete data)  | `docker compose down -v`         |

## 7. Team workflow (GitHub)

GitHub is the center. Each computer has its own copy.
Push sends your code up. Pull brings new code down. Nothing comes down by itself.

```
main -> pull -> new branch -> code -> commit -> push -> PR -> review -> merge -> delete branch
```

Rule: **1 task = 1 branch = 1 PR.** Always start a new branch from the latest `main`.

### Start of the day

```powershell
git checkout main
git pull
```

### Start a new task

```powershell
git checkout main
git pull
git checkout -b feature/<task-name>
```

Branch names:
- `feature/auth-register`: new feature
- `fix/login-error`: bug fix
- `docs/setup-guide`: docs only

### While working

Commit small and often. Push at the end of each day as a backup.

```powershell
git add .
git commit -m "[T12] Add register API"
git push -u origin feature/<task-name>
```

After the first push, `git push` is enough.

### Get new code from main into your branch

Do this when someone merges something you need, and always before opening a PR.

```powershell
git checkout main
git pull
git checkout feature/<task-name>
git merge main
```

### Open a Pull Request

```powershell
gh pr create --base main --title "[T12] Add register API" --body "What changed and how to test"
```

Then post the PR link in the Telegram group.

### Review a PR (for reviewers)

1. Open the PR on GitHub, then go to **Files changed**
2. Leave comments if something is unclear
3. **Review changes**, then **Approve**, then **Submit review**

You cannot approve your own PR. A pair's PR is reviewed by a different pair.

### After the PR is merged

GitHub deletes the remote branch automatically. Clean up your computer:

```powershell
git checkout main
git pull
git branch -d feature/<task-name>
git fetch --prune
```

### Conflicts

A conflict happens when two people change the same lines in the same file.

1. Open the file in VS Code or IntelliJ
2. Choose **Accept Current**, **Accept Incoming** or **Accept Both**
3. Save, then:

```powershell
git add .
git commit
```

Ask your pair or the leader if you are not sure which code to keep.

### Team rules

1. Never push to `main`. It is protected.
2. Keep PRs small, 1 to 2 days of work.
3. Pull often. Do not work on week-old code.
4. Tell the group before editing shared files (`application.yml`, `pubspec.yaml`, `docker-compose.yml`).
5. Never commit `.env`, passwords or build folders.
6. After merging something important, tell the group: "Merged X, please pull".
7. Merge with **Squash and merge** only.

## Common problems

- `database "julnow" does not exist`: add `-d postgres` to the psql command.
- The 3 databases are missing: the init script runs only once. Run `docker compose down -v` and then `docker compose up -d postgres`.
- `port is already allocated`: another Postgres is using port 5432. Stop it first.