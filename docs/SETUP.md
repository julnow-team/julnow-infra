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

## 7. Git workflow

```powershell
git checkout main
git pull
git checkout -b feature/<task-name>

# after coding
git add .
git commit -m "[T05] Short message"
git push -u origin feature/<task-name>
```

Then open a Pull Request on GitHub. One member must approve before merge.

## Common problems

- `database "julnow" does not exist`: add `-d postgres` to the psql command.
- The 3 databases are missing: the init script runs only once. Run `docker compose down -v` and then `docker compose up -d postgres`.
- `port is already allocated`: another Postgres is using port 5432. Stop it first.