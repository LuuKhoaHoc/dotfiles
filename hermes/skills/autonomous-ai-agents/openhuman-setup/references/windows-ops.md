# OpenHuman Windows Ops (PowerShell, not MSYS bash)

OpenHuman is a native Windows .exe. The Hermes terminal runs MSYS bash, which
mis-translates some `~/.openhuman` paths. Use PowerShell for every process/file
op on OpenHuman.

## Kill all OpenHuman (MSYS `taskkill //F` is unreliable)
```powershell
Stop-Process -Name OpenHuman -Force -ErrorAction SilentlyContinue
Start-Sleep 2
(Get-Process OpenHuman -ErrorAction SilentlyContinue).Count   # expect 0
```

## Remove the shadow `local` profile and pin the real one
```powershell
Remove-Item -Recurse -Force 'C:\Users\luukhoahoc\.openhuman\users\local' -ErrorAction SilentlyContinue
Set-Content -Path 'C:\Users\luukhoahoc\.openhuman\active_user.toml' `
  -Value 'user_id = "6a85f4f7018099b972f6ae17"' -Encoding utf8
Get-Content 'C:\Users\luukhoahoc\.openhuman\active_user.toml'
```

## Relaunch
```powershell
Start-Process 'C:\Users\luukhoahoc\AppData\Local\OpenHuman\OpenHuman.exe'
```

## Validate TOML (bash tomllib fails on /c/... paths — use PowerShell)
```powershell
python3 -c "import tomllib; d=tomllib.load(open(r'C:\Users\luukhoahoc\.openhuman\users\6a85f4f7018099b972f6ae17\config.toml','rb')); print('TOML OK', len(d))"
```

## Find the live config actually loaded
App logs the resolved path at boot:
```
grep "boot] paths:" ~/.openhuman/logs/openhuman.YYYY-MM-DD.log
# config=C:\...\users\LOCAL\config.toml  <-- BAD (shadow profile)
# config=C:\...\users\6a85...\config.toml <-- GOOD
```

## Why the shadow profile happens
On a fresh launch with no/invalid active_user.toml, OpenHuman creates
`users/local/` and writes an empty config there, ignoring your pre-built
profile. Fix = kill, delete `local`, write active_user.toml, relaunch.
