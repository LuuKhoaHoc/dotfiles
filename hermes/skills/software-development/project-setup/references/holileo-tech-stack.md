# Holileo Project - Reference Notes

## Tech Stack (July 2026)

| Layer | Choice | Version | Notes |
|-------|--------|---------|-------|
| Frontend | Next.js | 16.2.x | Turbopack default, React 19 |
| Auth + DB | Supabase | 1.26.x | @supabase/server SDK, custom OAuth |
| Package Manager | aube | latest | 6x faster than pnpm, reads all lockfiles |
| UI Library | shadcn/ui | v4 | Base UI (new default), not Radix |
| CSS | Tailwind CSS | 4.x | - |
| TypeScript | TypeScript | 5.x | - |
| Hosting | Vercel + Supabase | - | Free tier for demo |

## Key Discoveries

### aube Package Manager
- Created by jdx (mise creator)
- Install: `mise use -g aube`
- Reads/writes pnpm-lock.yaml, package-lock.json, yarn.lock, bun.lock
- Best security defaults (script jail, 24h cooling window)
- Rollback: rename aube-lock.yaml → pnpm-lock.yaml → pnpm install
- Risk: Vercel deployment untested

### shadcn/ui v4
- Now supports both Base UI and Radix UI
- Base UI is new default (Google/MUI team)
- CLI: `pnpm dlx shadcn@latest add accordion`
- Each component has Base UI and Radix UI tabs

### Supabase 2026 Changes
- New tables no longer auto-exposed to Data API
- Need explicit grants for PostgREST/GraphQL access
- @supabase/server SDK for edge/server runtimes
- Custom OAuth/OIDC providers supported

## User Preferences

- Vietnamese communication, English code/technical terms
- Friendly but concise tone
- Research-backed decisions (search web, don't guess)
- Documentation-first approach
- Decision flow: brainstorm → research → present options → user picks → document

## Project Structure

```
holileo/
├── apps/
│   ├── web/          # Next.js frontend
│   └── api/          # Reserved for future
├── docs/
│   ├── architecture.md
│   ├── requirements.md
│   └── database.md
├── supabase/
│   └── migrations/
└── README.md
```

## MVP Scope

Phase 1 (4-6 weeks):
- Auth (Admin, HR, Manager, Employee)
- Employee profiles (CRUD, search)
- Attendance (check-in/out)
- Payroll (calc + export PDF)

Phase 2 (2-3 weeks after):
- Leave requests
- Basic reports
