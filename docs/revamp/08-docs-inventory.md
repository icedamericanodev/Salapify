# 08. Docs inventory

Every file in docs/ as of 2026-09-11, with a verdict. Keep means it stays
in docs/ and remains current. Archive means git move to docs/archive with
no edits; it was true when written and is useful history. Superseded means
the same as archive, but this folder now holds the replacement, so nobody
should read the old one for direction.

| File | Verdict | Note |
|---|---|---|
| Salapify_Master_Constitution.md | Superseded, stays in place | Replaced by docs/revamp. Not moved because flutter/test/constitution_citation_test.dart reads its path; goes with flutter/ in Phase 4. |
| Product_Vision_Spec.md | Superseded | Replaced by 01-vision.md. Its cloud, AI coach and social ideas are Phase 5 material at best. |
| Product_Strategy.md, Product_Backlog.md, Roadmap_Recommendations.md, Sprint_Plan.md, Implementation_Plan.md | Superseded | Replaced by 05-roadmap.md. |
| Design_System.md, full_app_ui_ux_design_system_audit.md, salapify-ui-design-foundation-audit.md, salapify-ui-design-phase2-report.md, UX_Audit.md, Component_Review.md, Accessibility_Audit.md | Superseded | Replaced by 03 and 04. The full-app audit's Tarsi section informed 01 and 03 and is worth one read. |
| Current_Architecture.md, Folder_Structure_Review.md, Dependencies_Review.md, Database_Review.md, API_Review.md, Technical_Debt.md, Performance_Audit.md | Archive | All describe the React Native app. |
| Flutter_UI_Phase1_Plan.md, Flutter_UI_Phase2_Plan.md, Flutter_UI_Phase3_Plan.md | Archive | Plans for the app being replaced. |
| AI_Readiness.md, AI_Strategy.md | Archive | Pan is cut; the parser survives as code, not strategy. |
| Analytics.md, Monetization.md, Executive_Summary.md, Current_Features.md | Archive | Monetization's standing promises (core free forever, data portability never paywalled, early users keep Pro free) are carried into 01-vision.md by reference and still bind whenever v3 is offered to others. |
| Security_Audit.md, Risk_Register.md | Archive | Redo for v3 before it is offered to anyone else. |
| insights-v2-foundation-audit.md, money_courses_expansion_audit.md, money_courses_experience_audit.md | Archive | Courses are cut. |
| launch-checklist.md, play-store-listing.md | Archive | Redo at Phase 5, if and when v3 goes to the store. |
| adr/0001-durable-encrypted-store.md, adr/0002-privacy-release-evidence.md | Keep | Both still describe what v3 inherits. New decisions for v3 go to 07-decisions.md, then to adr/ when they become permanent. |
| features/unified-financial-accounts.md | Archive | Its four open decisions are answered by 04-screens.md's Accounts design. |
| reviews/ (all) | Archive | Per-stamp reports for the old app. Read one if a feature returns in Phase 5. |
| decision-log.md | Keep | Still the log for autonomous decisions. Its opening paragraph cites constitution section 46; that pointer is replaced by 09-working-rules.md. |
| delivery-log.md, qa-log.md, lunch-and-learn.md | Keep | Generated or appended logs; the delivery log is the only proof of what reached the phone and it continues for v3 with s3 stamps. |

After the move, docs/ contains: revamp/, adr/, archive/, decision-log.md,
delivery-log.md, qa-log.md, lunch-and-learn.md, and the constitution until
Phase 4.
