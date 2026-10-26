# HealthPM — Smart Healthcare Project Management System

HealthPM is a Flutter application for planning, monitoring and controlling the CSE-494 five-hospital healthcare delivery case study. The normal app launch connects to a hosted Supabase PostgreSQL database, uses Supabase Auth, and protects records with row-level security and database-side transaction functions.

## Run it

Requirements on this computer: Flutter 3.44+ and Chrome.

- Double-click `RUN_APP.bat` to run the Flutter source in Chrome.
- `supabase_config.json` contains the project URL and browser-safe publishable key used by the launchers. It must not contain a Supabase secret key or database password.
- Double-click `RUN_APP.bat` to run the Flutter source in Chrome with the Supabase configuration.
- To serve the release build, double-click `RUN_RELEASE.bat`. It builds with the Supabase configuration and opens at `http://localhost:3000/`. Keep the launcher window open while using it.

Create an account in the app or sign in with an existing account. The first confirmed Supabase Auth user is assigned the project admin role by a database trigger; access to all project tables requires a membership role. SQLite remains available for isolated automated tests. The hosted PostgreSQL schema and sample records are in `supabase/migrations/202610250001_healthpm.sql`. Windows desktop database support is included in the source. This computer does not have the Visual Studio C++ desktop build tools, so a Windows `.exe` could not be produced here.

## Assignment requirements covered

1. **Initiation and integration:** editable charter objective, stakeholders, scope boundary and project status; original/current budget and deadline; named role assignments for the project manager, two backend developers, two frontend developers, database developer and QA engineer; milestones; guarded closure records.
2. **Scope and WBS:** add/edit/prioritize/approve requirements; pending requirements stay outside approved scope; generated WBS includes work added through approved change requests; change requests record justification, cost, time and decision.
3. **Schedule and resources:** create work packages with owners, estimates, dates, dependency codes and a milestone flag; dependency-aware finish forecasts propagate delays; date-scaled Gantt bars show planned duration, earned progress, forecast delay and the deadline.
4. **Cost and EVM:** activity estimates and actual expenditure roll up to total planned budget; PV, EV, AC, CPI and SPI are calculated from database values; variance and below-threshold warnings are shown.
5. **Quality and risk:** defect severity/owner/status tracking; inspectable deliverable checklist; live 5×5 likelihood-impact prioritization matrix; PDPC responses generated from current risk records.
6. **Integration, validation and reporting:** all modules use the same Supabase records in the deployed app; input ranges, dates, work-package dependencies and closeout gates are validated; atomic database functions handle change decisions and closeout; the live report combines schedule, cost, scope, quality and risk indicators.

## Case study data

The seeded plan starts 03 Aug 2026, runs for 16 weeks to 23 Nov 2026, and has an approved budget of PKR 5,000,000. The demo reporting date is fixed at 25 Oct 2026 to keep EVM values repeatable. CR-001 proposes AI preliminary diagnosis and mobile delivery for PKR 800,000 and 21 additional days. Approving it updates the approved scope, budget and deadline (to 14 Dec 2026) and adds a dependent WBS work package in one transaction. Other approved changes add their own work packages rather than being misapplied as the AI change.

The sample records are synthetic project-management data; no patient records are stored.

## Submission files

- `lib/` — Flutter application and database integration.
- `database/schema.sql`, `database/sample_data.sql` — portable schema and starter case data.
- `supabase/migrations/` — hosted PostgreSQL schema, sample data, role policies and transactional functions.
- `supabase_config.json` — Supabase project URL and publishable client key; safe for browser use when RLS policies remain enabled.
- `TEST_CASES.md` — expected and observed scenario results.
- `test/database_test.dart` — 13 automated checks for seeded case data, EVM, timezone-stable dependency forecasts, editable schedule plans, cycle prevention, change control, requirements, validation, full quality-record edits, charter status and guarded closeout. `test/forms_test.dart` validates the reusable full-form workflow. Run the complete suite with `flutter test`.
- `DEMO_GUIDE.md` — short presentation script and setup notes.
- `screenshots/` — application views and actual Supabase SQL Editor screenshots showing hosted table counts and records.
- `build/web/` — compiled release application.

For a clean demo, use a new browser profile or clear the HealthPM site's local data so the original seeded project loads again.
