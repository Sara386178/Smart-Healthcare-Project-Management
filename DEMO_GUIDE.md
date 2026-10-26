# HealthPM demonstration guide

## Setup

Run `RUN_APP.bat` from the project folder. The app connects to the hosted Supabase database. On first use, create an app account; Supabase may ask you to confirm the email before signing in. The first account receives the admin role automatically. The report date is fixed at 25 Oct 2026 so the sample performance figures remain stable.

## Three-minute walkthrough

1. **Overview (20 sec):** introduce the five-hospital project. Show the PKR 5.0M approved budget, CPI/SPI, planned-vs-earned-vs-actual progress, pending CR-001, milestone and critical-defect alert.
2. **Scope & WBS (30 sec):** show six baseline requirements in scope and AI/mobile requirements excluded while pending. Open the change register and point out the justification and +PKR 800,000 / +21 day impact.
3. **Approve the change (25 sec):** approve CR-001. Show the transaction updating requirements, budget to PKR 5.8M, deadline to 14 Dec 2026, and adding the 4.1 work package. Return to the WBS to show approved change work included.
4. **Schedule & team (35 sec):** show owners and dependencies, the date-scaled planned/progress/forecast Gantt, milestone markers and the project deadline. Scroll the chart horizontally to see the full date range; click any work-package row to edit its dates, owner, duration, cost, dependencies or milestone setting. Explain how a predecessor delay moves dependent work.
5. **Cost & EVM (30 sec):** show PV, EV, AC, CPI and SPI, the formulas/variance and threshold warnings. Update a task's progress and actual expenditure, then show the roll-up change.
6. **Quality & risks (30 sec):** show defect severity/ownership/status, the release checklist, 5×5 risk matrix and live PDPC responses. Resolve a defect and show the dashboard count update.
7. **Reports & closeout (30 sec):** show the integrated project report. Attempt closeout while a critical defect or pending request remains to demonstrate the gate. Once all critical defects are resolved and all requests decided, record the summary and authorized approver.

Use **Edit charter** on Reports to update the objective, stakeholder list, scope boundary and project status. The form accepts Planning, On track or At risk; an approved change request sets the rebaselined status automatically. In Schedule & team, the Add activity flow includes an optional milestone marker. Activities are assigned to the case-study team roles, and added work can be assigned to a role or a combination of roles.

## Assessment evidence

Application screenshots and hosted Supabase database screenshots are in `screenshots/`. `TEST_CASES.md` lists the database regression scenarios, expected outcomes and observed results. The suite has 13 automated database tests plus one full-form widget test; run `flutter test`. `flutter analyze` currently reports informational style hints only. Use `RUN_RELEASE.bat` to build and serve the configured Chrome release locally.
