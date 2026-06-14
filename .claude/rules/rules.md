# Claude Code Rules — Kaizen (v2)

## Always read first
Before starting any task:
1. Read /CLAUDE.md — project overview, tech stack, principles
2. Read /AGENTS.md — who does what, build order, shared contracts
3. Read the relevant subdirectory CLAUDE.md (backend/CLAUDE.md, app/CLAUDE.md, etc.)

## Orchestration Rules
- **No Coding**: The orchestrator (you) must never write application code. Your job is to spawn specialized agents, review their work, and manage the process.
- **Verification First**: Never trust an agent's report. Always run `git status`, read the modified files, and execute tests/lints before committing.
- **Atomic Tasks**: One task = one atomic block (one feature + its unit test). Max 30 mins of real work. If a task is too big, split it.
- **Parallelism**: 
  - File-writing agents can run in parallel if they touch different directories.
  - **Never** run agents that execute `flutter build`, `flutter test`, or `jest` simultaneously (resource contention).
- **Context**: Always provide agents with the relevant `CLAUDE.md` from their subdirectory.

## Git & Workflow
- **Commit Format**: `feat(scope):`, `fix(scope):`, `docs:`, `refactor(scope):`.
- **Push Policy**: Push to `origin main` after every verified task. Standing authorization — commit AND push every block without asking.
- **Secrets**: Never commit `.env` or files containing keys. Use `git status` to check for accidental additions.

## Code & Quality Standards
- **Language**: English for all code, variable names, file names. Comments can be Russian.
- **Secrets**: Never put secrets (API keys, JWT secret) in code — use process.env / .env only.
- **Lints**: `flutter analyze` must return 0 errors.
- **Tests**: All existing tests must pass. New features must include unit tests. Mock AI calls in all tests.
- **Architecture**: Follow ADRs in `/docs/decisions.md`. Log new decisions immediately.

## File Rules
- Shared contracts (/docs/*.yaml, /docs/*.json, /docs/*.md) — read, never rewrite unless instructed.
- If you need to change a shared contract, ask first and log in /docs/decisions.md.
