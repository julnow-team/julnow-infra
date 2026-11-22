# JulNow Dev Setup

This guide has 5 parts:

- **Part A: First-time setup.** Do this once on your computer.
- **Part B: Daily work.** Start and stop what you need each day.
- **Part C: Team workflow.** How we use Git and GitHub together.
- **Part D: Project rules.** Ports, folders, database changes.
- **Part E: Common problems.**

Run every command in **PowerShell 7** (`pwsh`), not Windows PowerShell 5.

After each step, check the ✅ line. If it doesn't match, look at Part E or ask in the Telegram group.

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
| IntelliJ IDEA | https://www.jetbrains.com/idea |
| Android Studio | https://developer.android.com/studio |
| Flutter SDK | https://docs.flutter.dev/get-started/install |
| Node.js LTS | `winget install OpenJS.NodeJS.LTS` (for the admin web) |

**Free IntelliJ license:** apply at https://www.jetbrains.com/community/education with your `@rupp.edu.kh` email. Then in IntelliJ: **Help → Register → Log in to JetBrains Account → Activate**.

We use **JDK 21** for all Spring Boot services. Other JDK versions can stay installed; just pick 21 in IntelliJ (A5).

✅ Check:

```powershell
git --version
gh --version
docker --version
flutter --version
node --version
$PSVersionTable.PSVersion.Major
```

The last line must print `7`.

### A2. Set up Git and GitHub

Use the same name and email as your GitHub account:

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
gh auth login
```

For `gh auth login` choose: **GitHub.com → HTTPS → Login with a web browser**.

Then accept the invite to the **julnow-team** organization (check your email or https://github.com/julnow-team).

✅ Check: `gh auth status` shows `Logged in to github.com`.

### A3. Clone all repos

All repos go in `D:\julnow`:

```powershell
mkdir D:\julnow
cd D:\julnow
$repos = "julnow-infra","julnow-gateway","julnow-auth-service","julnow-listing-service","julnow-booking-service","julnow-admin-web","julnow-mobile"
foreach ($r in $repos) { git clone "https://github.com/julnow-team/$r.git" }
```

```
D:\julnow\
├── julnow-infra             Docker, database, docs
├── julnow-gateway           API Gateway
├── julnow-auth-service      Users, login, register
├── julnow-listing-service   Listings, categories, reviews
├── julnow-booking-service   Bookings, chat, notifications
├── julnow-admin-web         Admin dashboard (web)
└── julnow-mobile            Flutter app (tenant + owner)
```

✅ Check: `ls D:\julnow` shows 7 folders.

### A4. Start the database

Open **Docker Desktop** and wait until it says "Engine running".

```powershell
cd D:\julnow\julnow-infra
docker compose up -d postgres
docker compose ps
```

✅ Check: STATUS shows `(healthy)` and PORTS shows `5433->5432`.

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

### A7. Run a Spring Boot service

1. Make sure the database is running (A4).
2. In IntelliJ, open the service and its `...Application.java` file.
3. Click the green ▶ **Run** button at the top right.

✅ Check: the Run tab shows `Started ...Application in X seconds`.

The first run also creates the tables. You will see `Successfully applied N migration`.

Test it (Auth on port 8081 as an example):

```powershell
Invoke-RestMethod http://localhost:8081/actuator/health
```

✅ Check: it shows `status : UP`.

**Swagger** (see and test every API of a service in the browser):

```
http://localhost:8081/swagger-ui.html
```

Change the port for other services (see D1). Click an API, then **Try it out → Execute**.

To stop the service, click the red ■ **Stop** button.

### A8. Run the mobile app

**1. Create an emulator (once).**
In Android Studio: **More Actions → Virtual Device Manager → + → Create Virtual Device → Pixel 8 → Next**, choose the newest system image with ⭐ (download it if needed) **→ Finish**.

Want the emulator in its own small window? **File → Settings → Tools → Emulator** → untick `Launch in the Running Devices tool window`. Then drag a corner of the window to resize it.

**2. Start the emulator.**

```powershell
flutter emulators
flutter emulators --launch Pixel_8
```

Use the ID shown in the first column of `flutter emulators`.

✅ Check: `flutter devices` shows a line with `emulator-5554`.

**3. Run the app.**

```powershell
cd D:\julnow\julnow-mobile
flutter pub get
flutter run -d emulator-5554
```

The first build takes 2 to 5 minutes.

✅ Check: the emulator shows the JulNow home screen.

While it runs: press `r` to reload after you change code, `q` to quit.

**4. Using a real Android phone instead (optional).**
On the phone: **Settings → About phone → tap Build number 7 times**, then **Developer options → USB debugging ON**. Plug in with USB and tap **Allow**.

The phone cannot use `10.0.2.2` (see D3), so pass your computer's Wi-Fi IP:

```powershell
ipconfig | Select-String "IPv4"
flutter run --dart-define=API_URL=http://192.168.1.10:8080
```

Replace `192.168.1.10` with your IP. The phone and computer must be on the same Wi-Fi.

### A9. View the database in IntelliJ

The browser cannot open a database. Use the Database tool in IntelliJ:

1. Click the **Database** icon (cylinder) on the right side.
2. **+ → Data Source → PostgreSQL**.
3. Fill in the values from A6. Database: `postgres`.
4. If asked, click **Download missing driver files**.
5. Click **Test Connection**.
6. Go to the **Schemas** tab and tick `julnow_auth`, `julnow_listing`, `julnow_booking`.
7. Click **OK**.

✅ Check: you can open `julnow_auth → public → tables → users`. Double-click a table to see its rows.

A database only has tables after its service has run once (A7).

Quick look without IntelliJ:

```powershell
cd D:\julnow\julnow-infra
docker compose exec postgres psql -U julnow -d julnow_auth -c "\dt"
```

### A10. Run the admin web

The admin web is a React app (Vite + Tailwind). It has no database and no Java: it calls the Gateway, like the mobile app.

1. Start the database (A4), the gateway and the services you need (A7).
2. The first time, create `.env.local` in the repo folder with one line:

```
VITE_API_URL=http://localhost:8080
```

`.env.local` is never committed.

3. Install and run:

```powershell
cd D:\julnow\julnow-admin-web
npm install
npm run dev
```

✅ Check: open http://localhost:5173 and the admin login page shows.

While it runs, the page reloads by itself when you save a file. Press `Ctrl+C` in the terminal to stop.

Run `npm install` again after a pull that changes `package.json`.

---

## Part B: Daily work

### Database

Run these from `D:\julnow\julnow-infra`. Docker Desktop must be open.

| I want to... | Command |
|---|---|
| Start the database | `docker compose up -d postgres` |
| Check it is running | `docker compose ps` |
| Stop it (keep data) | `docker compose stop` |
| See its logs | `docker compose logs -f postgres` |
| Open SQL in a database | `docker compose exec postgres psql -U julnow -d julnow_auth` |
| Reset everything (deletes all data) | `docker compose down -v` |

### A normal day

1. Open Docker Desktop, then start the database.
2. Pull the latest code (C1).
3. Run the services you need in IntelliJ (A7).
4. Run the app if you work on mobile (A8), or `npm run dev` if you work on the admin web (A10).
5. At the end of the day: push your work (C3), stop the services, `docker compose stop`.

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

| Prefix | Use for | Example |
|---|---|---|
| `feature/` | new feature | `feature/auth-register` |
| `fix/` | bug fix | `fix/login-error` |
| `docs/` | docs only | `docs/setup-guide` |

Use a new branch name for every task. Never reuse a name that was already merged.

✅ Check: `git branch --show-current` shows your new branch.

### C3. Save your work

**Before every commit, check you are not on `main`:**

```powershell
git branch --show-current
```

Then:

```powershell
git add .
git status --short
git commit -m "[T12] Add register API"
git push -u origin feature/<task-name>
```

Look at `git status --short` before you commit. Only your own changed files should be there. No `target/`, `build/`, `.idea/` or `.env`.

After the first push, just `git push`. Commit small and often. Push at least once a day.

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
gh pr create --base main --head feature/<task-name> --title "[T12] Add register API" --body "What changed and how to test"
```

**Write your own title and body.** They must describe what you really changed. Don't copy the example.

✅ Check: it prints a link like `https://github.com/julnow-team/.../pull/5`.

Post the link in the Telegram group and ask for a review.

**Before you open a PR, check:**
- [ ] It runs on your computer without errors
- [ ] You merged the latest `main` (C4)
- [ ] No old migration file was changed (D2)
- [ ] No passwords or `.env` in the changes

### C6. Review a PR (for reviewers)

1. Open the PR link, then the **Files changed** tab.
2. Read the code. Comment if something is unclear.
3. Click **Review changes → Approve → Submit review**.

You cannot approve your own PR. A pair's PR is reviewed by a different pair.

After 1 approval, click **Squash and merge**. GitHub deletes the branch automatically.

### C7. After your PR is merged

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

### C9. Team rules

1. Never push to `main`. It is protected.
2. Keep PRs small: 1 to 2 days of work.
3. Pull often. Don't work on week-old code.
4. Tell the group before editing shared files (`application.yaml`, `pom.xml`, `pubspec.yaml`, `docker-compose.yml`).
5. Never commit `.env`, passwords or build folders.
6. After merging something important, tell the group: "Merged X, please pull".

---

## Part D: Project rules

### D1. Ports

| Service | Port | Database |
|---|---|---|
| Gateway | 8080 | none |
| Auth | 8081 | `julnow_auth` |
| Listing | 8082 | `julnow_listing` |
| Booking | 8083 | `julnow_booking` |
| Admin web | 5173 | none (calls the Gateway) |
| PostgreSQL | 5433 | all 3 |

### D2. Database changes (Flyway)

Tables are created only by Flyway files in `src/main/resources/db/migration/`. Hibernate never creates tables.

- File name: `V<number>__<what>.sql` with **two** underscores, for example `V2__create_otp_codes_table.sql`.
- Numbers go up: V1, V2, V3...
- **Never edit a migration file after it has been merged.** Not even a space. Flyway will stop with `checksum mismatch`.
- Need to change a table? Add a new file, for example `V3__add_phone_to_users.sql`.
- Two people adding a migration at the same time? Agree on the numbers in the group first.
- Enum columns are `VARCHAR` + `CHECK`, not Postgres `ENUM`, so they map to Java `@Enumerated(EnumType.STRING)`.

### D3. Who calls what

```
Mobile app / Admin web  →  Gateway (8080)  →  Auth / Listing / Booking
```

- The app and the admin web call **only the Gateway**, never a service port directly.
- A service never reads another service's database. If it needs data from another service, it calls that service's API.
- From the Android emulator, your computer is `10.0.2.2`, not `localhost`.
- The gateway allows the admin web at `http://localhost:5173` (CORS). Services do not need CORS.

### D4. Folder structure

**Spring Boot service.** Everything goes inside the main package, for example `com.julnow.auth`:

```
com.julnow.auth
├── auth       Register, login, OTP
├── user       User entity, repository, profile
├── security   JWT
├── common     Error handling, response format
└── config     Spring configuration
```

A class outside the main package is ignored by Spring.

**Flutter app.** One folder per feature, shared code in `core`:

```
lib/
├── core/        theme, router, network, widgets
└── features/
    └── <feature>/presentation/   screens for that feature
```

**Admin web (React).** Shared parts first, pages put them together:

```
src/
├── api/          calls to the Gateway
├── components/   shared UI: Button, Badge, Table, Dialog, Sidebar
├── pages/        one folder per screen: overview, users, listings ...
├── lib/          helpers: login token, money and date format
└── styles/       tokens.css (colours and spacing from Figma)
```

Use the colours from `tokens.css` through Tailwind. Do not write hex colours in a page.

### D5. Code style

- Write code that is simple and easy for teammates to read.
- Only add short comments where the code is not obvious.
- Follow the structure that is already in the repo.
- React: function components only. Keep the login token in memory, never in `localStorage`.
- Widgets: start with `StatelessWidget`. Use `ConsumerWidget` when you need a Riverpod provider. Use `StatefulWidget` only when you need a controller or `dispose()`.

---

## Part E: Common problems

| Problem | Fix |
|---|---|
| `password authentication failed for user "julnow"` | Another Postgres on Windows uses port 5432. Check your config uses port **5433**. |
| `database "julnow" does not exist` | Add `-d postgres` (or `-d julnow_auth`) to the `psql` command. |
| The 3 databases are missing | The init script only runs once. Run `docker compose down -v`, then `docker compose up -d postgres`. |
| `cannot connect to the Docker daemon` | Open Docker Desktop and wait for "Engine running". |
| Browser shows `ERR_EMPTY_RESPONSE` on `localhost:5433` | A database is not a website. Use IntelliJ (A9). |
| Browser shows `ERR_CONNECTION_REFUSED` on `localhost:8081` | The service is not running, or it crashed. Check the Run tab in IntelliJ. |
| IntelliJ: `JDK "temurin-21" is not found` | See A5 step 3. |
| Maven: `Could not transfer artifact ... from/to central` | Internet dropped. Click **Reload All Maven Projects** in the Maven panel. |
| Flyway: `checksum mismatch` | A migration file was changed. Run `git diff` on it and `git restore` it. See D2. |
| A Spring class does nothing (no error, no effect) | It is in the wrong package. See D4. |
| `flutter emulators --launch <...>` gives a ParserError | Replace `<...>` with the real ID, for example `Pixel_8`. |
| The app can't reach the API from a real phone | Use your computer's IP (A8 step 4), not `10.0.2.2`. |
| `git branch -d` says "not fully merged" | Use `git branch -D` after a Squash merge (C7). |
| `gh pr create` says "you must first push the current branch" | Add `--head <branch-name>`. |
| You committed on `main` by mistake | Don't push. Ask the leader. |
| `npm` is not recognized | Install Node.js (A1), then open a new terminal. |
| Admin web: `blocked by CORS policy` in the browser console | The gateway must allow `http://localhost:5173`. Pull the latest julnow-gateway and restart it. |
| Admin web shows a blank page | Check `.env.local` (A10) and look at the browser console (F12). |
