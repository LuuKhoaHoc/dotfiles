---
name: windows-rust-build
description: Use when cargo build fails on this Windows machine.
triggers:
  - "cargo build fails"
  - "install rust cli tool"
  - "link.exe extra operand"
  - "dlltool not found"
  - "rust build windows"
category: system-maintenance
---

# Windows Rust Build (no Visual Studio)

Use when building any Rust crate / installing a Rust CLI tool from source on this machine (agy-acp, `cargo install`, projects, ...).

## Environment facts (verified 2026-08-10)
- **NO Visual Studio / MSVC linker / Windows SDK installed.** The default MSVC toolchain (`stable-x86_64-pc-windows-msvc`) CANNOT link:
  - `link.exe` resolves to GNU coreutils (`/usr/bin/link.exe`) → `link: extra operand 'C:\...rcgu.o'` + `Try 'link --help'`
  - Windows SDK libs absent → `rust-lld: error: could not open 'kernel32.lib'`
  - Diagnose with `which -a link.exe` (shows the GNU shadowing).
- **MSYS path conversion is BROKEN**: native exes (git, curl, cmd) receiving POSIX path args (`/c/...`) silently resolve to `C:\c\...` — they write to the WRONG location. Symptoms: `git clone ... ~/x` → `fatal: destination path ... already exists` while `ls` shows nothing, with a stray copy at `/c/c/Users/<user>/...`; `cmd //c "dir ..."` swallows args and drops to interactive prompt.
- POSIX paths are fine for MSYS tools (bash builtins, ls, cp, python); use **Windows paths `C:\...`** for native exes. `MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1` blocks arg conversion for argv-heavy native invocations.

## Working recipe (verified)
```bash
# 1. Clone/operate with WINDOWS paths for native exes
git clone --depth 1 <url> 'C:\Users\luukhoahoc\Dev-Work\<repo>'

# 2. GNU toolchain (does NOT change default MSVC toolchain)
rustup toolchain install stable-x86_64-pc-windows-gnu

# 3. binutils for dlltool — windows-sys/windows-link build scripts need it
#    (error: "error calling dlltool 'dlltool.exe': program not found")
winget install -e --id BrechtSanders.WinLibs.POSIX.MSVCRT --accept-source-agreements --accept-package-agreements --silent
# dlltool lands at: $LOCALAPPDATA/Microsoft/WinGet/Packages/BrechtSanders.WinLibs.POSIX.MSVCRT_*/mingw64/bin/

# 4. Build
export MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1
export PATH="$LOCALAPPDATA/Microsoft/WinGet/Packages/BrechtSanders.WinLibs.POSIX.MSVCRT_*/mingw64/bin:$PATH"
export RUSTFLAGS='-C linker=C:\Users\luukhoahoc\.rustup\toolchains\stable-x86_64-pc-windows-gnu\lib\rustlib\x86_64-pc-windows-gnu\bin\rust-lld.exe'
cargo +stable-x86_64-pc-windows-gnu build --release
```

## Pitfalls
- Do NOT add `-C link-self-contained=yes` — `option not supported on this target`. The GNU sysroot already bundles all import libs (`lib/rustlib/x86_64-pc-windows-gnu/lib/self-contained/`).
- Long first builds (dependency download + compile): run background=true + notify_on_complete=true.
- Install the resulting binary into a dir already on PATH (e.g. `$LOCALAPPDATA/agy/bin/` next to agy.exe).
- RUSTFLAGS/PATH env vars do NOT persist across terminal sessions — re-export for every build, or document them in the project.

## Verify
- `binary --help` runs; for ACP adapters (agy-acp) run the JSON-RPC initialize handshake — see references/agy-acp-zed.md.

## Support files
- references/agy-acp-zed.md — agy-acp → Zed install detail: binary placement, Zed JSONC settings edit, ACP handshake test.
