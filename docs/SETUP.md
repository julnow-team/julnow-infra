# JulNow Dev Setup

This guide has 4 parts:

- **Part A: First-time setup.** Do this once on your computer.
- **Part B: Daily work.** Start and stop the database.
- **Part C: Team workflow.** How we use Git and GitHub together.
- **Part D: Common problems.**

Run every command in **PowerShell 7** (`pwsh`), not Windows PowerShell 5.

After each step, check the ✅ line. If it doesn't match, stop and look at Part D or ask in the Telegram group.

---

## Part A: First-time setup

### A1. Install the tools

| Tool | How to get it |
|---|---|
| Git | https://git-scm.com |
| GitHub CLI | `winget install GitHub.cli` |
| PowerShell 7 | `winget install Microsoft.PowerShell` |
| Docker Desktop | https://www.docker.com/products/docker-desktop |
| VS Code | https://code.visualstudio.com |
| JDK 21 (Temurin) | `winget install EclipseAdoptium.Temurin.21.JDK` |
| IntelliJ IDEA | https://www.jetbrains.com/idea (free with your `@rupp.edu.kh` email: jetbrains.com/community/education) |
| Flutter SDK + Android Studio | https://docs.flutter.dev/get-started/install |

We use **JDK 21** for all Spring Boot services. You can have other JDK versions installed too; just pick 21 in IntelliJ (see A5).

✅ Check:

```powershell
git --version
gh --version
docker --version
$PSVersionTable.PSVersion.Major
```

The last line must print `7`.

### A2. Log in to GitHub

```powershell
gh auth login
```

Choose: **GitHub.com → HTTPS → Login with a web browser**.

✅ Check: `gh auth status` shows `Logged in to github.com`.

### A3. Clone the repos

All repos go in the same folder, `D:\julnow`:

```powershell
mkdir D:\julnow
cd D:\julnow
git clone https://github.com/julnow-team/julnow-infra.git
git clone https://github.com/julnow-team/julnow-auth-service.git
```

Clone the others the same way when you need them:

```
D:\julnow\
├── julnow-infra             Docker, database, docs
├── julnow-gateway           API Gateway (port 8080)
├── julnow-auth-service      Auth service (port 8081)
├── julnow-listing-service   Listing service (port 8082)
├── julnow-booking-service   Booking service (port 8083)
├── julnow-admin-web         Admin dashboard
└── julnow-mobile            Flutter app
```

✅ Check: `ls D:\julnow` shows the folders you cloned.

### A4. Start the database for the first time

Open **Docker Desktop** first and wait until it says "Engine running".

```powershell
cd D:\julnow\julnow-infra
docker compose up -d postgres
docker compose ps
```

✅ Check: STATUS shows `(healthy)` and PORTS shows `5433->5432`.

Then check the 3 databases:

```powershell
docker compose exec postgres psql -U julnow -d postgres -c "\l"
```

✅ Check: the list has `julnow_auth`, `julnow_listing`, `julnow_booking`.

### A5. Open a Spring Boot service in IntelliJ

1. **File → Open**, choose the repo folder (for example `D:\julnow\julnow-auth-service`).
2. Click **Trust Project**.
3. **File → Project Structure → Project → SDK**: choose **21**.
   If 21 is not in the list: **Add SDK → JDK**, choose `C:\Program Files\Eclipse Adoptium\jdk-21...`.
4. Wait for Maven to finish downloading (progress bar at the bottom right).

✅ Check: the main `...Application.java` file has no red underlines.

### A6. Database connection info (local only)

| Key | Value |
|---|---|
| Host | `localhost` |
| Port | **`5433`** |
| User | `julnow` |
| Password | `julnow_dev_password` |
| Databases | `julnow_auth`, `julnow_listing`, `julnow_booking` |

We use port **5433**, not 5432, so it doesn't clash with a Postgres installed on Windows.

This password is for your own computer only. Real passwords go in `.env`, which is never committed.

---

## Part B: Daily work

Run these from `D:\julnow\julnow-infra`.

| I want to... | Command |
|---|---|
| Start the database | `docker compose up -d postgres` |
| Check it is running | `docker compose ps` |
| Stop it (keep data) | `docker compose stop` |
| See its logs | `docker compose logs -f postgres` |
| Open SQL in a database | `docker compose exec postgres psql -U julnow -d julnow_auth` |
| Reset everything (deletes all data) | `docker compose down -v` |

Docker Desktop must be open before any of these.
| Key      | Value               |
|----------|---------------------|
| Host     | localhost           |
| Port     | 5433                |
| User     | julnow              |
| Password | julnow_dev_password |

---

## Part C: Team workflow (Git + GitHub)

### How it works

GitHub is the center. Every computer has its own copy of the repo.

- **Push** sends your code up to GitHub.
- **Pull** brings new code down to your computer.
- New code never comes down by itself. You must pull.

```
main → pull → new branch → code → commit → push → PR → review → merge → delete branch
```

**Rule: 1 task = 1 branch = 1 PR.**

### C1. Start of the day

```powershell
git checkout main
git pull
```

### C2. Start a new task

Always start from the latest `main`:

```powershell
git checkout main
git pull
git checkout -b feature/<task-name>
```

Branch names:

| Prefix | Use for | Example |
|---|---|---|
| `feature/` | new feature | `feature/auth-register` |
| `fix/` | bug fix | `fix/login-error` |
| `docs/` | docs only | `docs/setup-guide` |

✅ Check: `git branch --show-current` shows your new branch.

### C3. Save your work

Commit small and often. Push at least once a day as a backup.

```powershell
git add .
git commit -m "[T12] Add register API"
git push -u origin feature/<task-name>
```

After the first push, just `git push`.

Commit message: `[Task ID] What you did`, for example `[T12] Add register API`.

### C4. Get new code from main into your branch

Do this when a teammate merges something you need, and **always before opening a PR**.

```powershell
git checkout main
git pull
git checkout feature/<task-name>
git merge main
```

If you see a conflict, go to C8.

### C5. Open a Pull Request

```powershell
gh pr create --base main --title "[T12] Add register API" --body "What changed and how to test"
```

✅ Check: it prints a link like `https://github.com/julnow-team/.../pull/5`.

Post the link in the Telegram group and ask for a review.

### C6. Review a PR (for reviewers)

1. Open the PR link, then the **Files changed** tab.
2. Read the code. Comment if something is unclear.
3. Click **Review changes → Approve → Submit review**.

You cannot approve your own PR. A pair's PR is reviewed by a different pair.

After 1 approval, click **Squash and merge**. GitHub deletes the branch automatically.

### C7. After your PR is merged

Clean up your computer:

```powershell
git checkout main
git pull
git branch -D feature/<task-name>
git fetch --prune
```

We use `-D` (capital D) because Squash merge makes a new commit, so Git cannot tell the branch was merged.

✅ Check: `git branch` shows only `main`.

### C8. Fix a conflict

A conflict happens when two people change the same lines in the same file.

1. Open the file in VS Code or IntelliJ. The conflict is marked with `<<<<<<<` and `>>>>>>>`.
2. Choose **Accept Current**, **Accept Incoming** or **Accept Both**.
3. Save, then:

```powershell
git add .
git commit
```

Not sure which code to keep? Ask your pair or the leader before committing.

### Team rules

1. Never push to `main`. It is protected.
2. Keep PRs small: 1 to 2 days of work.
3. Pull often. Don't work on week-old code.
4. Tell the group before editing shared files (`application.yaml`, `pubspec.yaml`, `docker-compose.yml`).
5. Never commit `.env`, passwords or build folders (`target/`, `build/`).
6. Never edit a Flyway file (`V1__...sql`) after it is merged. Add a new `V2__...sql` instead.
7. After merging something important, tell the group: "Merged X, please pull".

---

## Part D: Common problems

| Problem | Fix |
|---|---|
| `password authentication failed for user "julnow"` | You have another Postgres on Windows using port 5432. Check your config uses port **5433**. |
| `database "julnow" does not exist` | Add `-d postgres` (or `-d julnow_auth`) to the `psql` command. |
| The 3 databases are missing | The init script only runs once. Run `docker compose down -v`, then `docker compose up -d postgres`. |
| `docker: command not found` or `cannot connect to the Docker daemon` | Open Docker Desktop and wait for "Engine running". |
| IntelliJ: `JDK "temurin-21" is not found` | See A5 step 3: add the JDK 21 folder. |
| Maven: `Could not transfer artifact ... from/to central` | Internet dropped. Click **Reload All Maven Projects** in the Maven panel. |
| Flyway: `checksum mismatch` | Someone edited an old `V..sql` file. Undo that edit and add a new `V..sql` instead. |
| `git branch -d` says "not fully merged" | Use `git branch -D` after a Squash merge (see C7). |
2. Keep PRs small, 1 to 2 days of work.
3. Pull often. Do not work on week-old code.
4. Tell the group before editing shared files (`application.yml`, `pubspec.yaml`, `docker-compose.yml`).
5. Never commit `.env`, passwords or build folders.
6. After merging something important, tell the group: "Merged X, please pull".
7. Merge with **Squash and merge** only.

## Common problems

- `database "julnow" does not exist`: add `-d postgres` to the psql command.
- The 3 databases are missing: the init script runs only once. Run `docker compose down -v` and then `docker compose up -d postgres`.
- `password authentication failed for user "julnow"`: you have another Postgres installed on Windows using port 5432. JulNow uses port 5433, so make sure your config uses 5433.
