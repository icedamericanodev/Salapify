# SALAPIFY FLUTTER
# MASTER PRODUCT, ENGINEERING & AUTONOMOUS EXECUTION CONSTITUTION

**Status:** Foundational  
**Authority:** This document supersedes previous Salapify Flutter master plans, implementation frameworks, package plans, UI/UX plans, connector plans, and architectural guidance where conflicts exist.  
**Primary objective:** Evolve Salapify into a best-in-class personal finance management, budgeting, financial education, and financial intelligence application without unnecessarily discarding proven existing functionality.

---

# 1. PRODUCT NORTH STAR

Salapify is not merely a:

- budgeting app
- expense tracker
- finance calculator
- financial education app
- investment tracker
- AI chatbot

Salapify should become a **personal financial operating system**.

The product should help users:

> **Understand their money → control their money → plan their money → grow their money → become financially literate.**

Salapify should combine:

- financial management
- budgeting
- transaction tracking
- account management
- assets and liabilities
- goals
- financial tools
- reports
- insights
- investments
- financial education
- intelligent assistance
- Philippine financial context

into one coherent experience.

The user should never feel like they are switching between unrelated mini-apps.

Everything should feel like **one Salapify system**.

---

# 2. PRODUCT PRESERVATION PRINCIPLE

## Preserve first. Improve second. Replace only when justified.

The existing Salapify Flutter application contains product decisions, financial-management features, business logic, UX patterns, and implementation work that should not be discarded simply because a new architecture is being introduced.

The new framework is **not permission to rewrite Salapify from scratch**.

Before changing or removing existing functionality, Claude Code must determine:

1. What already exists?
2. What works well?
3. What users depend on?
4. What is architecturally sound?
5. What is incomplete?
6. What is duplicated?
7. What is technically weak?
8. What is inconsistent with the target architecture?
9. What can be improved incrementally?
10. What, if anything, genuinely needs replacement?

### Existing financial-management functionality has preservation priority.

Core financial-management capabilities should remain intact unless there is strong evidence that changing them is necessary.

Potential existing domains include:

- dashboard
- accounts
- transactions
- categories
- income
- expenses
- budgets
- assets
- liabilities
- debts
- goals
- recurring transactions
- reports
- insights
- financial calculations
- courses / financial education
- Pan
- tools

Do not remove a financial-management feature merely because the target architecture is different.

Migrate it.

Improve it.

Connect it.

---

# 3. PRODUCT PRINCIPLES

## 3.1 Financial clarity

Users should understand:

- what they own
- what they owe
- what they earn
- what they spend
- where their money goes
- whether they are improving
- what they can afford
- what risks they face
- what they should consider next

---

## 3.2 Financial management comes first

Salapify must remain useful even if the user never uses AI, investments, or advanced intelligence.

The financial-management foundation must remain strong.

The user should be able to:

- record money
- organize money
- manage accounts
- categorize transactions
- track income
- track expenses
- manage budgets
- track assets
- track liabilities
- manage debt
- create goals
- monitor cash flow
- understand net worth
- review reports
- act on insights

Advanced features must build on this foundation.

They must not weaken it.

---

## 3.3 Financial literacy

Salapify should not merely calculate.

It should explain.

A result should ideally answer:

> What happened?

> Why does it matter?

> What does this mean?

> What can I do next?

Education should be integrated into the financial experience.

Do not isolate financial literacy into a forgotten "Courses" section.

Connect education to actual user behavior.

Example:

```text
User records credit-card debt
        ↓
Debt analysis
        ↓
Insight
        ↓
"Why credit-card interest matters"
        ↓
Financial education
        ↓
Action
```

---

## 3.4 Local-first

Core financial functionality should work without an internet connection whenever technically and securely feasible.

Cloud services should enhance the experience.

They should not unnecessarily prevent users from accessing their own financial information.

---

## 3.5 Evidence before intelligence

Financial facts must come from deterministic application logic and verified data.

AI should interpret, explain, summarize, and assist.

AI must not become the financial source of truth.

---

## 3.6 Cohesion over feature count

Do not add features simply because competitors have them.

Every feature must fit the Salapify financial model.

A smaller coherent system is better than a large collection of disconnected features.

---

# 4. DESIGN AUTHORITY

## Figma is the primary product-design source of truth.

Figma should define:

- visual language
- information hierarchy
- interaction intent
- design tokens
- components
- variants
- states
- navigation
- responsive behavior
- visual hierarchy
- motion intent where documented

Flutter should implement that design intent.

Figma is not merely a screenshot repository.

---

# 5. FIGMA → FLUTTER → VISUAL QA

Use this loop:

```text
Figma
  ↓
Design Intent
  ↓
Design Tokens
  ↓
Reusable Components
  ↓
Flutter Implementation
  ↓
Rendered Application
  ↓
Visual QA
  ↓
Correction
  ↓
Validation
```

A screen is not complete simply because it compiles.

Validate:

- typography
- spacing
- alignment
- hierarchy
- colors
- icons
- dimensions
- component states
- responsiveness
- accessibility
- interaction
- motion

When working directly with Figma tooling, follow the applicable Figma workflow and skills.

Use Figma incrementally.

Validate changes after each meaningful operation.

---

# 6. DESIGN SYSTEM FIRST

Salapify must have one centralized design system.

Centralize:

### Color

- brand colors
- semantic colors
- income
- expense
- assets
- liabilities
- success
- warning
- error
- informational
- surfaces
- backgrounds

### Typography

- display
- headline
- title
- body
- label
- caption
- numeric/financial typography

### Spacing

Use a coherent spacing scale.

### Shape

- corner radius
- borders
- elevation
- cards
- sheets
- dialogs

### Components

- buttons
- cards
- inputs
- transaction rows
- account cards
- goal cards
- insight cards
- tool cards
- charts
- navigation
- bottom sheets
- dialogs
- filters
- date selectors
- empty states
- loading states
- error states

Do not solve design inconsistency screen-by-screen.

Fix the design system.

---

# 7. COMPONENT ARCHITECTURE

Every repeated UI pattern should have a reusable implementation.

Prefer:

```text
Design Token
    ↓
Primitive
    ↓
Component
    ↓
Feature Component
    ↓
Screen
```

Avoid:

```text
Screen A → custom implementation
Screen B → slightly different implementation
Screen C → another copy
```

If a component is visually or behaviorally the same, reuse it.

If it is intentionally different, model that difference explicitly through variants or composition.

---

# 8. FLUTTER IS THE PRIMARY EXPERIENCE PLATFORM

Flutter should be used to its full capability.

Prefer Flutter-native capabilities before adding dependencies.

Evaluate:

- widgets
- animations
- gestures
- transitions
- custom layouts
- CustomPainter
- Canvas
- clipping
- transforms
- shaders where justified
- semantics
- accessibility
- platform channels
- isolates/background processing where justified

Do not install a package merely because a package exists.

The question is:

> **What is the best engineering solution for this capability?**

Not:

> **Which package can do this fastest?**

---

# 9. TECHNOLOGY DECISION HIERARCHY

When implementing a capability, evaluate in this order:

```text
1. Existing Salapify implementation
2. Flutter/Dart native capability
3. Existing reusable architecture
4. Custom Flutter implementation
5. Existing approved package
6. Native Android/iOS capability
7. New pub.dev package
8. External service/API
```

The order can change when the capability inherently requires external infrastructure.

Document meaningful deviations.

---

# 10. PUB.DEV STRATEGY

Pub.dev is a toolbox.

It is not the architecture.

Use packages for capabilities where they provide meaningful value, such as:

- database engines
- networking
- image processing
- OCR
- secure storage
- notifications
- PDF generation
- advanced charting
- device integrations
- established infrastructure

Before adding a package, evaluate:

- whether Flutter already solves it
- whether the project already has a solution
- maintenance
- package quality
- API stability
- compatibility
- performance
- security
- licensing
- package size
- architectural impact

Every dependency must have a reason.

---

# 11. CONTEXT7 TECHNICAL AUTHORITY

Context7 is a development-time technical verification layer.

Use Context7 when current documentation matters for:

- Flutter APIs
- Dart APIs
- pub.dev packages
- package configuration
- package migration
- deprecated APIs
- unfamiliar APIs
- version-specific behavior
- current implementation patterns

Do not invent APIs.

Do not rely on outdated model memory when current documentation can be verified.

Use the repository's actual Flutter/Dart version as the compatibility baseline.

---

# 12. DEVELOPMENT CONNECTOR STRATEGY

The preferred development ecosystem is:

```text
Figma
 ↓
Design

Context7
 ↓
Technical documentation

GitHub
 ↓
Actual repository / PR / CI

Supabase
 ↓
Backend / database / sync

Specialized data connectors
 ↓
External financial information
```

Do not install connectors merely because they exist.

Each connector must solve a concrete development or product problem.

Avoid connector sprawl.

---

# 13. CONNECTOR GOVERNANCE

External connectors are **development and data infrastructure**, not hidden architecture.

For every external data connector document:

- source
- purpose
- freshness
- reliability
- licensing
- rate limits
- fallback
- caching
- failure behavior
- whether it is development-only or runtime
- whether the data can legally be displayed to users

Never assume that an MCP server or connector is appropriate for runtime use.

A Claude Code connector can help Claude research or develop a capability without becoming a dependency of the mobile application.

---

# 14. FINANCIAL DOMAIN MODEL

Salapify must have a central financial domain model.

Core entities may include:

```text
User
Account
Transaction
Category
Income
Expense
Asset
Liability
Debt
Goal
Budget
RecurringTransaction
Investment
Portfolio
Holding
FinancialMetric
FinancialInsight
FinancialEducation
```

Do not create isolated models for individual screens.

The domain model should support the entire application.

---

# 15. EXISTING FINANCIAL MANAGEMENT AS THE FOUNDATION

The existing financial-management layer must be treated as a first-class product foundation.

The audit must identify and preserve existing functionality across:

### Accounts

- cash on hand
- e-wallets
- cash in bank
- short-term investments
- long-term investments
- fixed assets
- bank accounts
- account balances
- account metadata
- masked account identifiers where applicable

### Liabilities

- credit cards
- loans
- debts
- payables
- mortgages
- other liabilities

### Transactions

- income
- expenses
- transfers
- categories
- recurring transactions
- dates
- notes
- payment/account associations

### Budgets

- budget creation
- category budgets
- period tracking
- actual vs budget
- remaining budget
- budget alerts

### Goals

- target amount
- current progress
- deadline
- contribution tracking
- projections
- suggested targets where appropriate

### Assets and Net Worth

- asset classification
- liability classification
- net worth
- historical changes
- financial position

### Reports and Insights

Preserve useful existing functionality and consolidate it where appropriate rather than creating duplicate systems.

---

# 16. FINANCIAL MANAGEMENT EXTENSION RULE

Existing financial-management features should be:

```text
PRESERVE
   ↓
UNDERSTAND
   ↓
VALIDATE
   ↓
CONNECT
   ↓
IMPROVE
   ↓
EXTEND
```

Do not:

```text
PRESERVE NOTHING
   ↓
REWRITE EVERYTHING
```

If a feature is incomplete, improve it.

If a feature is duplicated, consolidate it.

If a feature is poorly architected, migrate it incrementally.

If a feature is already strong, preserve it.

If a missing capability materially improves financial management, add it.

---

# 17. SALAPIFY FINANCIAL ENGINE

Create or strengthen a reusable financial engine.

Potential responsibilities:

- income calculations
- expense calculations
- cash flow
- net worth
- assets
- liabilities
- debt
- savings rate
- emergency fund
- budgets
- goals
- investments
- tax calculations
- forecasting
- financial health
- recurring transactions
- financial ratios
- date-based calculations
- Philippine-specific financial rules

The financial engine must be:

- deterministic
- testable
- reusable
- UI-independent
- package-independent
- API-independent
- AI-independent

---

# 18. SINGLE SOURCE OF FINANCIAL TRUTH

Use:

```text
Raw User Data
      ↓
Domain Model
      ↓
Financial Engine
      ↓
Validated Financial Facts
      ↓
Reports
Insights
Tools
Forecasts
Pan
```

Do not duplicate financial calculations across screens.

For example, savings rate must not be calculated differently by:

- Dashboard
- Reports
- Goals
- Pan
- Tax tools

There must be one authoritative calculation.

---

# 19. FINANCIAL FACTS VS AI

Separate:

### Financial truth

Generated by deterministic code and verified external data.

### Interpretation

Generated by rules and insights.

### Conversation

Generated by Pan.

Use:

```text
Financial Data
     ↓
Financial Engine
     ↓
Financial Facts
     ↓
Rules / Insights
     ↓
Pan
```

Never let an LLM invent financial figures.

---

# 20. PAN ARCHITECTURE

Pan should evolve into Salapify's financial intelligence interface.

Pan should understand structured context such as:

- income
- expenses
- accounts
- assets
- liabilities
- goals
- budgets
- investments
- financial trends
- financial insights
- education content
- relevant market data

Pan should be capable of explaining:

> What happened?

> Why?

> What does it mean?

> What should I consider?

> What could happen next?

AI should remain bounded by the financial engine.

---

# 21. FINANCIAL EDUCATION ENGINE

Financial literacy is a core product pillar.

Do not treat education as static articles alone.

Create a system that connects:

```text
Financial Event
      ↓
User Context
      ↓
Educational Concept
      ↓
Explanation
      ↓
Example
      ↓
Action
      ↓
Progress
```

Education topics may include:

- budgeting
- emergency funds
- debt
- credit cards
- loans
- saving
- investing
- stocks
- bonds
- funds
- MP2
- SSS
- PhilHealth
- Pag-IBIG
- taxes
- insurance
- retirement
- business finance
- financial scams
- financial planning

Use Philippine context wherever appropriate.

---

# 22. EDUCATION MUST CONNECT TO ACTION

Avoid:

> "Here is an article about emergency funds."

Prefer:

```text
User has ₱30,000 emergency savings
+
Monthly essential expenses = ₱25,000

Salapify:
"You currently have about 1.2 months of essential expenses covered."

Learn:
"How emergency funds work"

Calculate:
"Your recommended emergency fund"

Plan:
"Set an emergency fund goal"

Track:
"Monitor progress"
```

The education system should help users become capable of making financial decisions.

---

# 23. TOOLS ARCHITECTURE

Tools are not isolated calculators.

Tools should consume and contribute to the financial engine.

Examples:

```text
Tax Calculator
    ↓
Tax Result
    ↓
Income / Cash Flow
    ↓
Financial Insights
```

```text
Loan Calculator
    ↓
Debt Projection
    ↓
Cash Flow
    ↓
Financial Health
```

```text
Savings Calculator
    ↓
Goal Projection
    ↓
Goal Engine
    ↓
Progress
```

Tools may include:

- tax calculator
- BIR dates and tax references
- loan calculator
- savings calculator
- compound interest
- investment calculator
- inflation calculator
- budget calculator
- debt payoff
- emergency fund
- net worth
- financial health
- calculator with notes
- financial notes
- unit/currency utilities where useful

Tools should feel like part of Salapify.

---

# 24. REPORTS + INSIGHTS

Reports and Insights should form a connected financial intelligence layer.

The system should help answer:

### What do I own?

Assets.

### What do I owe?

Liabilities.

### What happened?

Transactions.

### Where did my money go?

Cash flow.

### Am I improving?

Trends.

### What should I consider?

Insights.

### What could happen?

Forecasts.

### What can I learn?

Education.

Reports should not become a separate silo.

Insights should consume validated report and financial-engine data.

---

# 25. INVESTMENT ARCHITECTURE

Investments should eventually support:

- Philippine stocks
- international stocks
- funds
- bonds
- other appropriate investment instruments

Potential data:

- price
- historical price
- portfolio value
- gain/loss
- dividends
- allocation
- cost basis
- performance
- PSEi/contextual market information

Do not hardcode market data.

Use verified data providers.

Investment functionality must complement the financial-management system rather than replace it.

---

# 26. PHILIPPINE FINANCIAL DATA LAYER

Salapify should prioritize Philippine financial relevance.

Potential sources include:

```text
PSE
BSP
BIR
SSS
PhilHealth
Pag-IBIG
SEC
PSA
```

Use official sources wherever possible.

External financial data must include:

- source attribution
- timestamp/freshness
- fallback behavior
- validation
- appropriate licensing

Never present unverified external financial data as authoritative.

---

# 27. MARKET DATA

For market data:

```text
External Market Source
        ↓
Market Data Service
        ↓
Normalization
        ↓
Caching
        ↓
Investment Domain
        ↓
Portfolio
        ↓
Insights
        ↓
Pan
```

Do not make Claude Code or an MCP server a runtime dependency.

A development connector can help research and validate data.

The actual application needs an appropriate runtime data architecture.

---

# 28. LOCAL-FIRST + CLOUD

Use:

```text
Flutter
 ↓
Application Layer
 ↓
Domain / Financial Engine
 ↓
Local Data
 ↓
Optional Sync
 ↓
Supabase
```

Supabase may provide:

- authentication
- sync
- backup
- remote configuration
- feature flags
- cloud data
- future collaboration features

Do not unnecessarily couple core functionality to Supabase availability.

---

# 29. CUSTOM CHARTING

Use the appropriate technology for each chart.

Possible approaches:

- Flutter-native rendering
- CustomPainter
- `fl_chart`
- other maintained packages

The decision should depend on:

- design fidelity
- interaction
- performance
- maintainability
- complexity

All charts must share one Salapify visualization language.

Potential visualizations:

- net worth
- cash flow
- income vs expense
- spending trends
- category allocation
- goals
- debt payoff
- investments
- portfolio allocation
- financial health
- money flow

---

# 30. MOTION SYSTEM

Create one motion language.

Motion should communicate:

- state
- hierarchy
- navigation
- progress
- success
- error
- change
- relationships

Use Flutter's native animation framework where practical.

Packages are allowed when they provide meaningful capability.

Do not animate everything.

---

# 31. NATIVE DEVICE CAPABILITIES

Evaluate native capabilities when they provide meaningful user value.

Potential capabilities:

### Security

- biometrics
- secure storage
- device authentication

### Notifications

- bills
- recurring transactions
- goals
- reminders
- financial events

### Camera

- receipt capture

### OCR

- merchant
- amount
- date
- receipt details

### Files

- CSV import
- CSV export
- backup
- reports

### Sharing

- reports
- financial summaries

### Deep links

- app navigation
- future integrations

### Platform features

- Android widgets
- iOS widgets
- shortcuts
- platform-specific capabilities where justified

Do not implement features simply because the platform supports them.

---

# 32. SECURITY

Financial data is sensitive.

Review:

- local storage
- authentication
- biometric protection
- sensitive fields
- account identifiers
- logs
- screenshots
- clipboard
- exports
- backups
- API keys
- Supabase policies
- network communication

Never hardcode secrets.

Never unnecessarily log financial data.

---

# 33. ACCESSIBILITY

Accessibility is part of product quality.

Review:

- text scaling
- semantic labels
- contrast
- touch targets
- screen readers
- dynamic content
- motion
- error communication
- charts and financial data accessibility

Do not make important financial information visual-only.

---

# 34. PERFORMANCE

Monitor:

- startup
- widget rebuilds
- lists
- charts
- database queries
- image loading
- animations
- memory
- background processing
- synchronization

Measure before optimizing.

Do not sacrifice architecture for premature optimization.

---

# 35. RESPONSIVE DESIGN

Design for:

- small Android phones
- large Android phones
- iPhones
- tablets where appropriate
- different text sizes
- accessibility settings

Avoid hardcoded screen assumptions.

Use responsive Flutter layouts.

---

# 36. DESIGN + ENGINEERING CONSISTENCY

A new feature is not complete until it satisfies all relevant layers:

```text
Product requirement
        ↓
Figma
        ↓
Design system
        ↓
Flutter component
        ↓
Domain model
        ↓
Financial engine
        ↓
Data layer
        ↓
Tests
        ↓
Accessibility
        ↓
Visual QA
        ↓
Release
```

Do not allow features to bypass the architecture merely because they are small.

---

# 37. FEATURE INTEGRATION RULE

Every new feature must answer:

1. Which user problem does it solve?
2. Which existing domain does it belong to?
3. Does an existing Salapify feature already solve part of this problem?
4. What should be preserved?
5. What should be improved?
6. Which data does it consume?
7. Which data does it produce?
8. Which financial calculations does it use?
9. Which existing components can it reuse?
10. Which Figma design defines it?
11. Does it work offline?
12. Does it require native capability?
13. Does it require a package?
14. Does it require an external data source?
15. How does it contribute to financial literacy?
16. How does it connect to Insights?
17. How does Pan use it?
18. How will it be tested?

If these questions cannot be answered, the feature is not ready for implementation.

---

# 38. CLAUDE CODE OPERATING MODEL

Claude Code operates as:

**Senior Flutter Architect + Product Engineer + UX Engineer + Financial Domain Engineer + Technical Researcher.**

Before modifying code:

```text
Inspect
 ↓
Understand
 ↓
Research
 ↓
Design
 ↓
Plan
 ↓
Implement
 ↓
Test
 ↓
Visual QA
 ↓
Review
 ↓
Document
 ↓
Continue
```

Do not jump directly from request to code.

Claude should use autonomous engineering judgment wherever the decision is safe.

---

# 39. AUTONOMOUS EXECUTION & DECISION AUTHORITY

Salapify development follows an **autonomous-by-default** execution model.

Claude Code is expected to think, investigate, decide, implement, test, validate, and continue without unnecessarily waiting for founder approval.

The founder should not be required to approve routine engineering decisions.

---

## 39.1 Autonomy principle

When a decision is:

- low risk
- reversible
- technically well-supported
- consistent with this constitution
- consistent with the existing architecture
- consistent with the approved Figma/design system
- unlikely to materially change product behavior

Claude Code should make the decision and continue.

Do not stop merely because multiple technically valid options exist.

Choose the strongest option based on:

1. Product value
2. Architecture
3. Maintainability
4. Security
5. Performance
6. UX
7. Offline capability
8. Existing project conventions
9. Dependency minimization
10. Long-term sustainability

Document meaningful decisions.

Continue execution.

---

# 40. DECISION HIERARCHY

Use this hierarchy:

```text
Founder Direction
      ↓
Master Constitution
      ↓
Existing Product Architecture
      ↓
Existing Financial Management
      ↓
Figma / Design System
      ↓
Flutter / Dart Best Practice
      ↓
Verified Documentation
      ↓
Repository Conventions
      ↓
Engineering Judgment
```

When the answer is clear from the hierarchy, Claude should proceed without asking.

---

# 41. AUTONOMOUS DECISIONS

Claude Code MAY decide and implement without waiting for approval when dealing with:

### Code

- refactoring
- component extraction
- naming
- file organization
- cleanup
- duplication removal
- test creation
- error handling
- state management improvements
- performance improvements
- accessibility improvements

### Flutter

- Flutter-native implementation choices
- widget composition
- animation implementation
- layout implementation
- CustomPainter where appropriate
- responsive behavior
- platform conventions

### Packages

Claude may add, replace, or remove a package when:

- the decision is clearly justified
- it does not create significant architectural risk
- the package is maintained and compatible
- the package materially improves the implementation
- Flutter-native implementation is inferior for the requirement

Document the decision and continue.

### Design

Claude may make minor design decisions when:

- Figma does not specify the detail
- the decision follows the established design system
- the decision does not alter product intent

### Testing

Claude should proactively create and run appropriate tests.

Do not wait for approval to fix failing tests caused by the implementation.

### Documentation

Claude should update relevant documentation when architecture or behavior changes.

---

# 42. FOUNDER DECISION REQUIRED

Claude MUST stop and ask the founder when a decision materially affects:

### Product direction

Examples:

- removing a major feature
- changing the primary navigation model
- changing Salapify's core positioning
- changing the fundamental financial model
- introducing a major monetization strategy
- changing the target user

### Financial behavior

Examples:

- changing financial calculation definitions
- changing tax methodology
- changing financial-health scoring
- changing investment calculations
- changing financial recommendations

### Security / Privacy

Examples:

- handling highly sensitive financial information differently
- changing authentication architecture
- exposing user data externally
- introducing a new third-party data processor
- weakening encryption or security controls

### Architecture

Examples:

- replacing the primary state-management architecture
- replacing the database architecture
- replacing local-first architecture
- major Supabase restructuring
- introducing a fundamentally different backend

### External cost

Examples:

- paid APIs
- recurring infrastructure costs
- paid data providers
- AI API architecture that creates meaningful recurring costs

### Irreversible or high-impact changes

Examples:

- destructive migrations
- deleting significant user data
- removing a major subsystem
- breaking public APIs
- major repository restructuring that is difficult to reverse

### Brand / Design

Examples:

- changing the Salapify visual identity
- changing brand colors
- changing typography strategy
- changing mascot identity
- replacing the established design language

---

# 43. TWO-TIER DECISION MODEL

## TIER 1 — AUTONOMOUS

Claude decides and continues.

Examples:

```text
Use AnimatedContainer instead of a package
Extract reusable Card component
Add widget tests
Fix spacing inconsistency
Improve accessibility label
Optimize list rendering
Replace deprecated API
Use existing design token
Add error state
Refactor duplicated calculation
Improve an existing financial-management feature without changing its core behavior
```

No approval required.

---

## TIER 2 — FOUNDER APPROVAL

Claude pauses.

Examples:

```text
Replace database
Change financial-health methodology
Introduce paid market-data provider
Change subscription model
Remove major feature
Change navigation architecture
Change financial calculation definition
Expose financial data to third-party service
Change core product positioning
```

Present:

1. Decision required
2. Why it matters
3. Options
4. Recommended option
5. Impact
6. Reversibility
7. Cost/risk

Then wait.

---

# 44. DO NOT ASK UNNECESSARY QUESTIONS

Before asking the founder a question, Claude must ask itself:

> "Can I make this decision safely using the constitution, repository evidence, Figma, Context7, and engineering judgment?"

If yes:

**Make the decision.**

Do not ask.

If no:

Determine whether the uncertainty is material.

If it is not material:

Choose the safest reasonable option.

If it is material:

Ask the founder.

---

# 45. BATCH SAFE DECISIONS

Do not interrupt execution for every individual decision.

If ten related decisions are Tier 1, make all ten decisions and continue.

Do not ask:

> "Should I use this widget?"

> "Should I extract this component?"

> "Should I add this test?"

> "Should I rename this class?"

Make the appropriate engineering decision.

---

# 46. DECISION LOG

For autonomous decisions that materially affect implementation, maintain a lightweight decision log.

Record:

- decision
- reason
- alternatives considered
- evidence
- impact

Example:

```text
Decision:
Use Flutter-native AnimationController instead of package X.

Reason:
The required animation is simple and already supported by Flutter.

Evidence:
Current Flutter version supports the required API.

Impact:
No new dependency.
Lower maintenance burden.
```

Do not create excessive documentation for trivial decisions.

---

# 47. FAILURE RECOVERY

If an autonomous implementation causes:

- test failures
- analyzer errors
- build failures
- visual regressions
- integration failures

Claude should diagnose and correct the issue autonomously when the correction remains within Tier 1 authority.

Do not stop at the first failure.

Use:

```text
Failure
 ↓
Diagnose
 ↓
Fix
 ↓
Test
 ↓
Validate
 ↓
Continue
```

Stop only if the failure exposes a Tier 2 decision.

---

# 48. PHASE EXECUTION

Once a phase has been approved, Claude should execute that phase end-to-end.

Do not stop after every task.

For example:

```text
Phase 3 — Experience System
```

Claude should:

```text
Audit
 ↓
Plan
 ↓
Implement
 ↓
Test
 ↓
Visual QA
 ↓
Fix
 ↓
Retest
 ↓
Complete Phase
```

Only stop if:

1. A founder-level decision is required
2. A security boundary is reached
3. Required external access is unavailable
4. The implementation would violate this constitution
5. The next action is irreversible/high-risk
6. A material product decision is ambiguous

---

# 49. FOUNDER COMMUNICATION FORMAT

When a founder decision is required, do not dump the entire technical investigation.

Use:

## DECISION REQUIRED

**Decision:**  
[One sentence]

**Why it matters:**  
[Short explanation]

**Recommended:**  
[Option]

**Alternatives:**  
[Option A / Option B]

**Impact:**  
[Cost / architecture / UX / security]

**Reversibility:**  
[Easy / Moderate / Difficult]

**My recommendation:**  
[Clear recommendation]

Then wait.

---

# 50. EXECUTION PHILOSOPHY

The founder provides:

- product vision
- strategic direction
- major constraints
- high-impact decisions

Claude provides:

- investigation
- technical reasoning
- implementation
- testing
- validation
- routine decisions
- continuous improvement

The goal is not to maximize founder approvals.

The goal is to maximize **high-quality autonomous progress while protecting founder authority over consequential decisions.**

---

# 51. DEFAULT BEHAVIOR

When uncertain:

### Low impact

Choose and continue.

### Medium impact but reversible

Choose the safest architecture and document it.

### High impact

Ask.

### Irreversible

Ask.

### Financial methodology

Ask.

### Security/privacy boundary

Ask.

### Product strategy

Ask.

### Routine engineering

Do it.

---

# 52. CORE RULE

> **Do not make the founder approve work that Claude can safely decide.**

> **Do not make a founder-level decision without the founder.**

Everything between those two rules belongs to autonomous engineering judgment.

---

# 53. PACKAGE / CONNECTOR / NATIVE DECISION MATRIX

For every new capability, produce when the decision is non-trivial:

| Option | Capability | Cost | Risk | Maintenance | Offline | UX Fidelity | Recommendation |
|---|---|---:|---:|---:|---:|---:|---|
| Flutter native | | | | | | | |
| Custom | | | | | | | |
| Existing package | | | | | | | |
| New package | | | | | | | |
| Native API | | | | | | | |
| External service | | | | | | | |
| Connector/MCP | | | | | | | |

Choose based on product value and architecture.

Do not generate the matrix for trivial decisions.

---

# 54. TESTING

Every financial calculation must have deterministic tests.

Cover:

- normal values
- zero
- negative values where valid
- rounding
- missing data
- date boundaries
- recurring calculations
- forecast calculations
- tax scenarios
- edge cases

Important user journeys should have integration coverage.

Examples:

```text
Add transaction
 ↓
Balance changes
 ↓
Cash flow changes
 ↓
Insight updates
```

```text
Create goal
 ↓
Contribution
 ↓
Progress
 ↓
Forecast
 ↓
Insight
```

```text
Add liability
 ↓
Net worth changes
 ↓
Debt metrics
 ↓
Financial health
```

Preserved existing financial-management features must retain their intended behavior unless a documented improvement intentionally changes it.

---

# 55. VISUAL QA

For major UI changes:

1. Compare with Figma.
2. Check component consistency.
3. Check typography.
4. Check spacing.
5. Check responsive behavior.
6. Check accessibility.
7. Check loading/error/empty states.
8. Check interaction.
9. Check animation.
10. Check dark/light/system themes if supported.

Do not accept "close enough" when the design system already defines the intended behavior.

---

# 56. PHASED IMPLEMENTATION FRAMEWORK

The application should evolve through coherent layers.

## PHASE 0 — DISCOVERY, PRESERVATION & AUDIT

Inspect:

- repository
- architecture
- existing financial-management features
- Figma
- dependencies
- Context7-relevant technology
- connectors
- financial logic
- Pan
- Tools
- Reports
- Insights
- Accounts
- Goals
- database
- Supabase
- native integrations
- tests
- performance
- security

Explicitly classify existing features:

```text
KEEP
IMPROVE
CONSOLIDATE
MIGRATE
REPLACE
DEFER
REMOVE
```

Do not remove or replace existing financial-management features during Phase 0.

No production changes.

---

## PHASE 1 — FOUNDATION

Establish:

- architecture boundaries
- design system
- tokens
- component system
- financial domain boundaries
- testing foundations
- local-first boundaries

Preserve compatible existing implementations.

---

## PHASE 2 — FINANCIAL ENGINE

Centralize and connect:

- transactions
- accounts
- assets
- liabilities
- cash flow
- net worth
- budgets
- goals
- debt
- savings
- financial health
- calculations

Migrate existing financial logic into the financial engine incrementally.

Do not duplicate it.

---

## PHASE 3 — EXPERIENCE SYSTEM

Implement approved Figma direction.

Strengthen:

- navigation
- typography
- cards
- charts
- motion
- gestures
- states
- accessibility
- responsive layouts

Preserve good existing user workflows.

Improve weak ones.

---

## PHASE 4 — TOOLS

Integrate:

- tax
- BIR dates
- loans
- savings
- investments
- calculator
- notes
- financial utilities

Connect them to the financial engine.

---

## PHASE 5 — REPORTS + INSIGHTS

Create or consolidate:

- financial position
- income statement
- cash flow
- net worth
- trends
- financial health
- actionable insights
- forecasts

Preserve useful existing Reports and Insights functionality while consolidating duplicate logic.

---

## PHASE 6 — FINANCIAL EDUCATION

Connect financial events to:

- lessons
- explanations
- examples
- calculators
- action plans
- progress

Expand the existing course/education system only where it improves financial outcomes.

---

## PHASE 7 — PAN

Build structured financial intelligence.

Use:

- financial facts
- rules
- insights
- context
- education
- optional AI

Preserve useful existing Pan capabilities while moving intelligence toward the structured architecture.

---

## PHASE 8 — INVESTMENTS

Build the investment domain.

Evaluate:

- PSE
- international stocks
- funds
- bonds
- portfolio tracking
- dividends
- performance
- market data

---

## PHASE 9 — NATIVE CAPABILITIES

Prioritize:

1. Biometrics
2. Notifications
3. Files
4. Receipt capture
5. OCR
6. Sharing
7. Widgets
8. Deep links
9. Platform-specific features

---

## PHASE 10 — CLOUD + SYNC

Strengthen:

- Supabase
- synchronization
- backup
- feature flags
- conflict handling
- offline recovery

---

## PHASE 11 — PRODUCTION HARDENING

Perform:

- security review
- performance review
- accessibility review
- dependency audit
- integration testing
- visual QA
- release validation

---

# 57. DO NOT REWRITE THE APPLICATION

Preserve good existing work.

Refactor only when there is evidence of:

- duplication
- architectural conflict
- maintainability problems
- performance issues
- security issues
- broken design consistency
- incorrect financial logic
- obsolete APIs
- unnecessary dependencies

Prefer incremental migration.

The burden of proof is on replacement, not preservation.

---

# 58. DO NOT CREATE FUTUREWARE

Do not create:

- empty abstraction layers
- unused interfaces
- speculative repositories
- unnecessary services
- hypothetical AI infrastructure
- unnecessary packages
- placeholder integrations

Build architecture around real current consumers.

Keep the architecture extensible without turning it into an enterprise maze.

---

# 59. DEFINITION OF DONE

A feature is complete when:

- product requirement is satisfied
- existing compatible functionality is preserved
- Figma direction is implemented where applicable
- design system is followed
- reusable components are used
- financial logic uses the financial engine
- tests pass
- analyzer is clean or documented
- accessibility is reviewed
- offline behavior is preserved where required
- security implications are reviewed
- performance is acceptable
- external data is sourced appropriately
- Pan integration is considered
- financial education opportunity is considered
- documentation is updated

---

# 60. PHASE 0 REQUIRED OUTPUT

Before changing the repository, produce an evidence-based audit.

## A. Current Architecture

What actually exists.

## B. Existing Strengths

What should be preserved.

## C. Existing Financial Management

Inventory the current financial-management functionality.

For each capability identify:

- current implementation
- current UX
- current data model
- dependencies
- strengths
- weaknesses
- dependencies
- downstream consumers
- preservation recommendation

## D. Architecture Gaps

What should change and why.

## E. Design Audit

Figma vs current Flutter.

## F. Design System Audit

Typography, colors, spacing, components, states, motion.

## G. Package Audit

KEEP / REQUIRED / REPLACE / REMOVE / DEFER.

## H. Flutter Capability Audit

What can be implemented natively/custom.

## I. Connector Audit

Existing and potentially useful connectors.

## J. Financial Engine Audit

Duplicate and missing financial logic.

## K. Pan Audit

Current architecture and target architecture.

## L. Financial Education Audit

How education currently works and where it should connect to financial behavior.

## M. Local-first Audit

Current offline capability and weaknesses.

## N. Native Capability Audit

Potential Android/iOS capabilities.

## O. Investment Data Audit

Potential PSE/global market data architecture.

## P. Security Audit

Financial-data risks.

## Q. Performance Audit

Current risks.

## R. Target Architecture

Propose the architecture based on the actual repository.

## S. Preservation & Migration Plan

Explain:

- what stays
- what improves
- what consolidates
- what migrates
- what gets replaced
- what gets deferred
- what, if anything, should be removed

Do not recommend removal without evidence.

## T. Prioritized Roadmap

Rank by:

- user value
- architectural dependency
- risk
- effort
- financial impact
- literacy impact
- preservation priority

---

# 61. PHASE 0 STOP CONDITION — UPDATED

When running the initial master audit:

**STOP AFTER THE AUDIT.**

Do not make production changes during Phase 0.

The purpose of the stop is to establish the target architecture and identify any founder-level decisions.

The stop does **not** mean Claude should ask permission for every future implementation step.

After Phase 0 is reviewed and the phase direction is approved, Claude should execute subsequent approved phases autonomously under the Tier 1/Tier 2 decision model.

---

# 62. FINAL PRODUCT STANDARD

Every future Salapify decision should pass this test:

> **Does this make Salapify more useful, more coherent, more trustworthy, more financially educational, or more capable of helping users make better financial decisions?**

And:

> **Does this preserve or improve valuable existing financial-management capability?**

If yes:

Evaluate the best implementation.

If no:

Do not build it merely because the technology exists.

---

# SALAPIFY END STATE

The long-term system should converge toward:

```text
                         SALAPIFY
                            │
             ┌──────────────┼──────────────┐
             ↓              ↓              ↓
        EXPERIENCE     FINANCIAL       INTELLIGENCE
             │           ENGINE              │
             │              │                Pan
             │              │             Insights
             │              │            Forecasting
             │              │             Education
             │              │
             └──────────────┼──────────────┘
                            ↓
                    FINANCIAL MANAGEMENT
                            │
             ┌──────────────┼──────────────┐
             ↓              ↓              ↓
          Accounts      Transactions      Budgets
             ↓              ↓              ↓
        Assets/Liabs    Cash Flow         Goals
             └──────────────┼──────────────┘
                            ↓
                       LOCAL-FIRST
                            │
                     ┌──────┴──────┐
                     ↓             ↓
                  Offline        Sync
                                   │
                               Supabase
                                   │
                    ┌──────────────┼──────────────┐
                    ↓              ↓              ↓
                   PSE            BSP            BIR
                    ↓              ↓              ↓
              Investments      Economic       Tax Tools
                               Context
```

And the development workflow:

```text
                         PRODUCT IDEA
                              │
                              ↓
                     EXISTING SALAPIFY
                              │
                              ↓
                       PRESERVE FIRST
                              │
                              ↓
                           FIGMA
                              │
                              ↓
                       DESIGN SYSTEM
                              │
                              ↓
                         FLUTTER
                              │
              ┌───────────────┼───────────────┐
              ↓               ↓               ↓
         Flutter Native   Pub.dev         Native APIs
              │               │               │
              └───────────────┼───────────────┘
                              ↓
                       DOMAIN ENGINE
                              │
                     FINANCIAL ENGINE
                              │
              ┌───────────────┼───────────────┐
              ↓               ↓               ↓
            Tools          Insights          Pan
              │               │               │
              └───────────────┼───────────────┘
                              ↓
                       LOCAL-FIRST DATA
                              │
                              ↓
                         SUPABASE
                              │
                              ↓
                        CLOUD / SYNC

Technical verification:
Context7

Repository:
GitHub

Design:
Figma

External specialized data:
Approved connectors / APIs

Validation:
Tests + Visual QA + Security + Performance
```

---

# FINAL GOVERNING RULE

**Build Salapify as one system.**

Not as a collection of screens.

Not as a collection of packages.

Not as a collection of connectors.

Not as a collection of AI features.

Not as a rewrite of the existing application.

Build on what already works.

Strengthen the financial-management foundation.

Use Flutter to its full capability.

Use Figma as the design authority.

Use Context7 for technical verification.

Use connectors where they provide real value.

Use packages selectively.

Use native capabilities where appropriate.

Use deterministic financial logic as the source of truth.

Use Pan as the intelligence interface.

Use financial education to turn information into better financial decisions.

And let Claude Code move autonomously unless a decision genuinely belongs to the founder.

> **Preserve what works. Improve what is weak. Add what is missing. Replace only when justified. Automate everything safe. Escalate only what matters.**
