# Salapify v3 — Personal Financial Operating System

## Product Vision

Salapify v3 is not intended to be merely:

- A budgeting app
- An expense tracker
- A bill tracker
- A net-worth tracker
- An investment tracker
- An AI chatbot

The objective is to build a **Personal Financial Operating System**.

The app is the interface. The real product is the financial system underneath it.

The system should understand the relationship between:

- Income
- Cash
- Accounts
- Spending
- Bills
- Debt
- Credit cards
- Savings
- Goals
- Investments
- Insurance
- Government benefits
- Family obligations
- Financial risks
- Financial behavior
- Future plans
- Major life events

These should not exist as disconnected features. They should interact with one another.

---

# 1. Core Product Thesis

Most personal finance apps organize information.

Salapify should organize the user's **financial life**.

The fundamental product shift is:

> Traditional finance apps tell users where their money went.
>
> Salapify should help users understand where their money is going, where it will go next, and what they can do about it.

The system should progress through:

**TRACK → UNDERSTAND → PREDICT → DECIDE → IMPROVE → GROW**

The ultimate question Salapify should answer is:

> **"What should I do with my money next?"**

---

# 2. Financial Life Loop

Salapify should model the user's complete financial lifecycle:

```text
                         INCOME
                           │
                           ▼
                       ALLOCATION
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
         ESSENTIALS       GOALS         WEALTH
             │             │             │
             ▼             ▼             ▼
         SPENDING       SAVING       INVESTING
             │             │             │
             └─────────────┼─────────────┘
                           ▼
                       OBLIGATIONS
                           │
                           ▼
                       CASH FLOW
                           │
                           ▼
                      FORECASTING
                           │
                           ▼
                    FINANCIAL RISKS
                           │
                           ▼
                       DECISIONS
                           │
                           ▼
                         ACTION
                           │
                           ▼
                      OUTCOME
                           │
                           └──────────────► NEXT CYCLE
```

A financial event should not simply create a transaction.

It should potentially affect the user's:

- Financial state
- Cash flow
- Safe-to-spend
- Goals
- Debt
- Financial health
- Forecast
- Risks
- Recommendations

---

# 3. Financial State

Instead of thinking:

> "The user has transactions."

Think:

> **"The user has a financial state."**

That state changes continuously.

Conceptually:

```text
Financial State
│
├── Income
│   ├── Salary
│   ├── Freelance
│   └── Other income
│
├── Liquidity
│   ├── Cash
│   ├── Bank accounts
│   └── E-wallets
│
├── Obligations
│   ├── Bills
│   ├── Debt
│   ├── Credit cards
│   └── Installments
│
├── Goals
│   ├── Emergency fund
│   ├── Short-term goals
│   ├── Major purchases
│   └── Long-term goals
│
├── Assets
│   ├── Cash
│   ├── Savings
│   ├── Investments
│   ├── MP2
│   ├── Property
│   └── Other assets
│
├── Liabilities
│   ├── Credit cards
│   ├── Loans
│   └── Other liabilities
│
├── Protection
│   ├── Insurance
│   ├── HMO
│   └── Emergency reserves
│
├── Behavior
│   ├── Spending patterns
│   ├── Income patterns
│   ├── Saving patterns
│   └── Financial habits
│
└── Future
    ├── Forecasts
    ├── Scenarios
    ├── Life events
    └── Financial independence
```

---

# 4. Financial Graph

Think of the user's finances as a connected graph rather than isolated features.

Example:

```text
Salary
  │
  ▼
Payday
  │
  ├────────────► Rent
  │
  ├────────────► Credit Card
  │                  │
  │                  ▼
  │              Installments
  │
  ├────────────► Emergency Fund
  │
  ├────────────► MP2
  │
  └────────────► Discretionary Spending
                       │
                       ▼
                    Behavior
                       │
                       ▼
                    Insights
                       │
                       ▼
                   Decisions
```

Example:

If a user adds a ₱60,000 credit-card installment, the system should understand that it changes:

- Monthly cash flow
- Credit utilization
- Safe-to-spend
- Future disposable income
- Goal completion date
- Debt obligations
- Financial health
- Forecasted cash balance

That is the difference between a tracker and a system.

---

# 5. Single Source of Financial Truth

Create a central financial engine.

Core calculations should include:

- Current balance
- Available cash
- Safe-to-spend
- Cash flow
- Net worth
- Debt
- Credit utilization
- Goal progress
- Emergency fund
- Savings rate
- Spending rate
- Financial health
- Forecast
- Financial runway
- Scenario outcomes

Every screen should consume the same underlying financial state.

Avoid:

```text
Dashboard = calculation A
Reports   = calculation B
Goals     = calculation C
Pan       = calculation D
```

Instead:

```text
                  FINANCIAL ENGINE
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Dashboard       Goals           Pan
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                  SAME FINANCIAL TRUTH
```

Core financial calculations should be deterministic and testable.

Do not rely on an LLM for financial arithmetic.

---

# 6. Three Time Dimensions

A strong financial system understands three dimensions.

## PAST — What happened?

- Transactions
- Spending
- Income
- Historical trends
- Behavior

## PRESENT — Where am I?

- Current cash
- Current debt
- Current goals
- Current net worth
- Current financial health
- Current safe-to-spend

## FUTURE — What happens next?

- Upcoming bills
- Expected income
- Forecast
- Goals
- Debt payoff
- Life events
- Scenarios
- Retirement
- Financial independence

Salapify should connect all three.

---

# 7. Transaction → Insight → Decision → Action

Important financial events should follow this chain:

```text
DATA
  ↓
CONTEXT
  ↓
INTERPRETATION
  ↓
INSIGHT
  ↓
DECISION
  ↓
ACTION
  ↓
OUTCOME
```

Example:

Transaction:

₱850 food delivery

↓

Context:

User has already exceeded dining budget by 18%.

↓

Insight:

Dining spending is trending above target.

↓

Decision:

Reduce discretionary food spending.

↓

Action:

Adjust remaining weekly dining budget.

↓

Outcome:

User remains within monthly target.

The long-term goal is to move users from data to action with minimal effort.

---

# 8. Core System Pillars

## Pillar 1 — KNOW

Where is my money?

Features:

- Accounts
- Transactions
- Categories
- Budgets
- Income
- Expenses
- Bills
- Recurring transactions
- Debt
- Credit cards
- Assets
- Liabilities
- Net worth
- Balance sheet
- Cash flow
- Investments
- Savings
- Goals

Maintain:

> **Assets - Liabilities = Net Worth**

Do not reduce personal finance to income minus expenses.

---

## Pillar 2 — PREDICT

What will happen?

Features:

- Cash-flow forecast
- Upcoming obligations
- Expected income
- Payday forecast
- Goal forecast
- Debt payoff forecast
- Bill anomaly detection
- Income anomaly detection
- Emergency runway
- Long-term scenarios

Forecast periods:

- 7 days
- 14 days
- 30 days
- 90 days
- 6 months
- 12 months

Example:

```text
CURRENT CASH       ₱38,500
UPCOMING BILLS    -₱12,300
CARD PAYMENT       -₱8,500
EXPECTED SALARY   +₱35,000
GOAL CONTRIBUTION  -₱5,000
--------------------------------
PROJECTED BALANCE  ₱47,700
```

Pan can explain the result in natural language.

---

## Pillar 3 — DECIDE

What should I do?

Features:

- Can I afford this?
- Safe-to-spend
- Debt versus savings trade-offs
- Goal trade-offs
- Purchase simulator
- Credit-card simulator
- Scenario engine
- Financial decision engine

---

## Pillar 4 — IMPROVE

What should I change?

Features:

- Spending insights
- Financial leakage
- Lifestyle inflation
- Subscription intelligence
- Bill anomaly detection
- Income anomaly detection
- Behavioral patterns
- Monthly financial autopsy
- Financial health
- Risk detection

---

## Pillar 5 — GROW

How do I build financial resilience and wealth?

Features:

- Emergency fund
- Savings goals
- Sinking funds
- MP2
- Investments
- Retirement planning
- Financial independence
- Inflation planning
- Long-term goals

---

# 9. High-Value Features to Adapt from the Market

The global finance market already validates several feature categories.

Salapify should adopt proven concepts where they improve the product:

### Budgeting

- Category budgets
- Zero-based/envelope-inspired allocation
- Flexible budgets
- Sinking funds
- Rollover
- Budget targets

### Cash flow

- Future balance projections
- Recurring income
- Recurring bills
- Expected transactions
- Cash-flow calendar

### Bills

- Recurring bills
- Due dates
- Bill reminders
- Upcoming obligation summaries
- Bill anomaly detection

### Goals

- Target amount
- Deadline
- Current progress
- Required contribution
- Alternative contribution scenarios

### Debt

- Debt accounts
- Interest rate
- Minimum payment
- Extra payment
- Avalanche
- Snowball
- Payoff forecast

### Credit cards

- Statement balance
- Current balance
- Due date
- Credit limit
- Utilization
- Installments
- Interest calculations

### Wealth

- Assets
- Liabilities
- Net worth
- Investments
- Net-worth history

### Household

- Shared finances
- Household goals
- Family obligations

Do not copy competitor features blindly.

Use proven concepts as building blocks for the larger system.

---

# 10. Salapify White-Space Opportunities

These are potential areas where Salapify can build differentiation.

These should be treated as product opportunities, not claims that absolutely no competitor anywhere has ever implemented them.

## 10.1 Financial Operating System

Connect:

```text
Income
 ↓
Allocation
 ↓
Spending
 ↓
Bills
 ↓
Debt
 ↓
Goals
 ↓
Investments
 ↓
Net Worth
 ↓
Forecast
 ↓
Risk
 ↓
Decision
```

The key differentiator is the connection between these domains.

---

## 10.2 Safe-to-Spend

Do not only show current balance.

Calculate:

> **How much can I safely spend without compromising upcoming obligations, goals and minimum cash reserves?**

Inputs can include:

- Current cash
- Upcoming bills
- Debt payments
- Credit-card obligations
- Savings goals
- Minimum cash buffer
- Expected income
- Recurring expenses
- Payday schedule

Example:

```text
SAFE TO SPEND

₱6,850

Next salary:
September 30

Days remaining:
15

Suggested discretionary allowance:
₱456/day
```

---

## 10.3 Payday-Based Budgeting

Support:

- Monthly salary
- Semi-monthly salary
- Weekly income
- Biweekly income
- Irregular income
- Freelance income
- Multiple income sources

Question to answer:

> **"What does this paycheck need to cover?"**

Example:

```text
SEPTEMBER 15 PAYDAY

Income              ₱35,000

Rent                ₱10,000
Credit card          ₱6,000
Savings              ₱5,000
MP2                  ₱2,000
Food/transport       ₱7,000
Flexible spending    ₱5,000
```

---

## 10.4 Can I Afford This?

Signature feature.

User enters:

> "Can I afford a ₱45,000 phone?"

Evaluate:

- Current cash
- Upcoming bills
- Debt
- Credit cards
- Emergency fund
- Goals
- Expected income
- Forecast

Return:

### COMFORTABLE

Purchase does not materially affect financial health.

### POSSIBLE

Purchase is affordable but delays goals or reduces flexibility.

### NOT RECOMMENDED

Purchase creates a cash-flow problem or violates the user's financial safety threshold.

Example:

> "You can technically afford this, but buying it today would delay your emergency-fund goal by approximately two months."

---

## 10.5 What-If Scenario Engine

Allow users to simulate:

- Salary increase
- Salary decrease
- Job loss
- New job
- New rent
- New car
- New house
- Marriage
- Baby
- Travel
- Major purchase
- Debt payoff
- Investment contribution
- Savings increase
- Savings decrease
- Overseas relocation
- Career break
- Freelancing

The scenario should recalculate:

- Cash flow
- Safe-to-spend
- Emergency runway
- Goal completion
- Debt capacity
- Financial health
- Net worth

---

## 10.6 Credit Card Intelligence

Track:

- Credit limit
- Available credit
- Current balance
- Statement balance
- Statement date
- Due date
- Minimum payment
- Full payment
- Interest
- Installments
- Remaining installments
- Monthly installment obligations
- Utilization

Include:

> "What happens if I only pay the minimum?"

Show:

- Estimated interest
- Estimated payoff period
- Estimated total repayment
- Additional cost

Clearly label assumptions.

---

## 10.7 Credit Card Installment Simulator

Input:

```text
Purchase:       ₱60,000
Term:           12 months
Monthly rate:   0.5%
```

Calculate:

- Monthly payment
- Total interest
- Total repayment
- Cash-flow impact
- Credit utilization impact
- Difference versus cash purchase

Example:

```text
Cash purchase:      ₱60,000
Installment total:  ₱63,600
Difference:          ₱3,600
```

Explain the trade-off instead of merely calculating the payment.

---

## 10.8 Financial Leakage

Identify:

- Food delivery
- Coffee
- Ride-hailing
- Shopping
- Entertainment
- Subscriptions
- Small frequent purchases

Example:

> "You made 27 food-delivery purchases this month."

> "Average purchase: ₱320."

> "Total: ₱8,640."

> "That represents 17% of your monthly savings target."

---

## 10.9 Lifestyle Inflation Detector

Compare income growth versus spending growth.

Example:

```text
Income:
₱40k → ₱55k → ₱75k

Income growth:
+87.5%

Lifestyle spending:
₱32k → ₱45k → ₱66k

Spending growth:
+106%
```

Insight:

> "Your lifestyle spending is growing faster than your income."

Only make this insight when supported by actual user data.

---

## 10.10 Financial Health

Create a transparent score.

Example:

```text
FINANCIAL HEALTH

78 / 100

Cash Flow          88
Emergency Fund     62
Debt               71
Spending Control   82
Savings            76
Investments        54
Protection         65
```

Explain the score.

Do not create a meaningless gamified number.

Always identify the biggest issue and a recommended action.

---

## 10.11 Financial Risk Engine

Detect:

- Cash-flow shortfall
- Low emergency fund
- High credit utilization
- Excessive debt
- Increasing lifestyle expenses
- Unusual spending
- Income reduction
- Large upcoming obligations
- Goal shortfall
- Subscription creep
- Insurance/protection gaps
- Concentrated assets
- Excessive cash holdings

Example:

```text
RISK DETECTED

Credit utilization:
72%

Impact:
High

Suggested action:
Reduce card balance before
making another large purchase.
```

Thresholds should be configurable and transparent.

---

# 11. Philippine Financial Operating System

The Philippine market should be a major initial advantage.

Salapify should deeply understand Philippine financial life while keeping the underlying architecture globally extensible.

Relevant areas:

- PHP
- Pag-IBIG
- MP2
- SSS
- PhilHealth
- GSIS
- HMO
- 13th-month pay
- Philippine holidays
- Credit-card installments
- GCash
- Maya
- Digital banks
- Government loans
- Housing loans
- Auto loans
- Salary loans
- OFW remittances
- Family support

Do not hard-code Philippine assumptions into the global financial engine.

Use a country-specific rules/configuration layer.

Conceptually:

```text
GLOBAL FINANCIAL ENGINE
        │
        ├── Philippines Rules
        ├── United States Rules
        ├── Australia Rules
        └── Future Countries
```

---

# 12. Philippine-Specific Opportunities

## 12.1 MP2 Planner

Support:

- Target amount
- Contribution frequency
- Contribution amount
- Five-year maturity planning
- Historical dividend scenarios
- Conservative/base/higher assumptions
- Dividend reinvestment scenarios
- Lump-sum versus periodic contribution

Never guarantee future returns.

Clearly separate:

- Historical data
- Assumptions
- Projections

---

## 12.2 13th-Month Planner

Example:

```text
Monthly salary:
₱50,000

Estimated 13th month:
₱50,000
```

Ask:

> "What do you want your 13th month to accomplish?"

Possible allocations:

- Emergency fund
- Debt payoff
- MP2
- Investments
- Travel
- Family support
- Shopping
- Flexible spending

Example:

```text
Emergency fund   ₱20,000
Debt             ₱15,000
MP2              ₱10,000
Flexible          ₱5,000
```

---

## 12.3 Philippine Holiday Cash-Flow Engine

Consider:

- Regular holidays
- Special non-working holidays
- Weekends
- Payday schedules
- Bill due dates
- Expected income dates
- Business/banking day considerations

Purpose:

Detect potential timing pressure.

Do not assume exact bank processing behavior.

---

## 12.4 Family Support

Track:

- Parents
- Children
- Siblings
- Grandparents
- Dependents

Track:

- Monthly support
- Medical support
- Education
- Allowances
- One-time assistance

Show financial impact without judgment.

---

## 12.5 OFW / Remittance Mode

Support:

- Recipient
- Currency
- Exchange rate
- Transfer fee
- Purpose
- Frequency
- Monthly total
- Annual total

Example:

> "You sent approximately ₱180,000 home this year."

Show:

- Total transferred
- Fees
- FX impact
- Recurring commitments

---

# 13. Emergency Mode

Allow the user to activate:

## FINANCIAL EMERGENCY MODE

Calculate:

- Essential monthly expenses
- Current liquid assets
- Emergency runway
- Minimum debt payments
- Essential bills
- Discretionary spending

Potential recommendations:

PAUSE:

- Non-essential goals
- Subscriptions
- Discretionary spending

PRIORITIZE:

- Housing
- Food
- Utilities
- Healthcare
- Debt minimums
- Cash preservation

Example:

> "Your current emergency runway is approximately 2.7 months."

---

# 14. Job Loss Simulator

Question:

> "What happens if I lose my job?"

Calculate:

- Liquid savings
- Essential monthly expenses
- Debt obligations
- Monthly burn rate
- Emergency runway

Scenarios:

- 3 months
- 6 months
- 9 months
- 12 months

Example:

> "You need approximately ₱30,000 more to reach a six-month emergency reserve."

---

# 15. Life Event Simulator

Model:

- Marriage
- Baby
- Moving out
- Buying a car
- Buying a house
- Career break
- Job loss
- Overseas relocation
- Freelancing
- Supporting parents
- Going back to school

Estimate:

- Upfront cost
- Monthly cost
- Required emergency fund
- Goal impact
- Cash-flow impact
- Net-worth impact

---

# 16. Financial Calendar

Create a financial calendar showing:

- Income
- Bills
- Debt
- Credit cards
- Goals
- Investments
- Important financial dates

Example:

```text
Sept 15   Salary
Sept 18   Credit-card statement
Sept 20   Electricity
Sept 25   MP2 contribution
Sept 30   Salary
Oct 1     Rent
Oct 5     Insurance
```

Overlay projected cash balance.

---

# 17. Subscription and Bill Intelligence

Detect:

- New recurring charges
- Increased recurring charges
- Duplicate subscriptions
- Forgotten subscriptions
- Annual renewals
- Unusual bills

Example:

> "Your electricity bill is approximately 91% above your recent normal range."

Use historical user data.

---

# 18. Income Anomaly Detection

Example:

Expected:

₱50,000

Actual:

₱44,500

Insight:

> "Your income is ₱5,500 below your expected amount."

Do not assume the reason.

Let the user investigate.

---

# 19. Monthly Financial Autopsy

Create a monthly summary.

Example:

```text
WHERE DID YOUR MONEY GO?

Income              ₱75,000
Essentials           ₱31,500
Debt                  ₱8,000
Savings              ₱10,000
Investments           ₱5,000
Wants                ₱13,500
Uncategorized         ₱7,000
```

Then explain the largest financial issue.

Example:

> "Your biggest issue this month wasn't overspending. ₱7,000 remained unplanned."

---

# 20. What Changed?

Compare periods.

Example:

> "Your spending increased by ₱6,240."

Breakdown:

```text
Food          +₱2,300
Transport     +₱1,400
Shopping      +₱1,800
Utilities       +₱740
```

Identify the largest drivers.

---

# 21. Financial Autopilot

Use observed recurring patterns to generate a suggested plan.

Detect:

- Salary dates
- Recurring bills
- Typical spending
- Savings behavior
- Debt payments
- Goal contributions

Example:

```text
RECOMMENDED MONTHLY PLAN

Income             ₱75,000
Essentials          ₱32,000
Debt                 ₱8,000
Goals               ₱15,000
Flexible spending   ₱12,000
Buffer                ₱8,000
```

The user must approve changes.

Never silently change financial allocations.

---

# 22. Financial Education → Action

Money Courses should connect directly to the financial engine.

Example:

Lesson:

> Emergency Fund

After completion:

```text
APPLY THIS TO MY FINANCES

Essential monthly expenses:
₱28,000

Recommended emergency fund:
₱168,000

Current:
₱72,000

Gap:
₱96,000

Recommended contribution:
₱8,000/month
```

Education should produce an actionable financial plan.

---

# 23. Investment Visibility

Do not become a brokerage.

Provide visibility.

Example:

```text
Cash          48%
Savings       22%
MP2           12%
Stocks         8%
Crypto         5%
Other          5%
```

Explain allocation.

Avoid guaranteed-return language.

Avoid pretending that Salapify is an investment adviser unless the product eventually obtains the appropriate regulatory framework.

---

# 24. Inflation Planning

For long-term goals:

```text
Current target:
₱1,000,000

Inflation-adjusted target:
₱1,340,000
```

Clearly label assumptions.

Do not present projections as guarantees.

---

# 25. Financial Independence

Track:

```text
Annual essential expenses:
₱480,000

Investable assets:
₱2.4M

Coverage:
5× annual essential expenses
```

Explain the metric.

Do not represent it as a guaranteed retirement outcome.

---

# 26. Behavioral Finance Layer

Detect patterns such as:

- Payday spending spikes
- Weekend spending spikes
- End-of-month restriction
- Impulse purchases
- Subscription creep
- Lifestyle inflation
- Small-purchase accumulation
- Recurring overspending

Example:

> "Your discretionary spending is consistently highest during the three days after payday."

Recommendations should be actionable.

Do not shame the user.

---

# 27. Pan — Decision Interface

Pan should NOT simply be a chatbot.

Bad:

> "You spent more on dining this month."

That is just a chatbot reading a report.

Good:

User:

> "Can I buy a ₱30k phone?"

Pan:

> "You technically can, but I wouldn't recommend buying it this week. Your credit-card payment is due in nine days and your projected cash buffer would fall below your target. If you wait until your next salary, you can make the purchase while keeping your emergency reserve intact."

Pan should have access to:

- Current financial state
- Upcoming obligations
- Goals
- Cash-flow forecast
- Debt
- Credit cards
- Financial health
- Scenario results
- Relevant financial history

The financial engine performs calculations.

Pan explains and contextualizes them.

---

# 28. Pan Architecture

Conceptually:

```text
USER
 │
 ▼
PAN
 │
 ▼
DECISION ENGINE
 │
 ├── Financial State
 ├── Forecast Engine
 ├── Goal Engine
 ├── Debt Engine
 ├── Budget Engine
 ├── Risk Engine
 ├── Scenario Engine
 └── Behavioral Engine
 │
 ▼
RECOMMENDATION
 │
 ▼
USER ACTION
```

Use deterministic logic for financial calculations.

Use AI for:

- Explanation
- Conversation
- Contextualization
- Summarization
- Natural-language interaction
- Personalized coaching

---

# 29. Proactive Intelligence

Eventually Salapify should not require the user to ask every question.

Examples:

> "Your electricity bill is 46% higher than usual."

> "You have three large payments coming within the next 10 days."

> "You're on track to miss your ₱100k travel goal by ₱8,500."

> "Your spending increased faster than your income over the last three months."

> "You have enough cash to cover upcoming obligations while maintaining your minimum buffer."

The system should surface important information at the right time.

Avoid notification spam.

---

# 30. Financial State Categories

Potential states:

### Stable

Cash-flow positive, obligations covered, goals progressing.

### Tight

Bills covered but little discretionary cash.

### At Risk

Projected cash shortfall or significant financial risk.

### Debt Heavy

Large portion of income directed toward debt.

### Goal Focused

Strong savings and goal behavior.

### Building

Emergency fund and savings increasing.

### Wealth Building

Increasing assets and net worth.

### Financial Emergency

Income interruption or major unexpected expense.

The UI and recommendations can adapt to the user's state.

---

# 31. Recommended Domain Model

Do not design the database around screens.

Avoid:

```text
DashboardTable
BudgetScreenTable
ReportsTable
PanTable
```

Think in terms of financial entities:

```text
User
Account
Transaction
Category
Income
Bill
RecurringTransaction
Budget
Goal
SinkingFund
Debt
Loan
CreditCard
Installment
Asset
Liability
Investment
Insurance
Benefit
FinancialEvent
Scenario
Forecast
FinancialState
Insight
Risk
Recommendation
Document
```

Screens should consume these domain objects.

---

# 32. Recommended Architecture

Keep financial logic separate from UI.

Conceptual architecture:

```text
PRESENTATION
│
├── Dashboard
├── Accounts
├── Budget
├── Goals
├── Bills
├── Debt
├── Reports
├── Calendar
├── Scenarios
├── Insights
└── Pan
        │
        ▼
APPLICATION / USE CASES
        │
        ▼
FINANCIAL INTELLIGENCE
│
├── Forecast Engine
├── Decision Engine
├── Risk Engine
├── Scenario Engine
├── Insight Engine
├── Behavioral Engine
└── Recommendation Engine
        │
        ▼
FINANCIAL DOMAIN
│
├── Accounts
├── Transactions
├── Income
├── Bills
├── Budgets
├── Goals
├── Debt
├── Credit Cards
├── Assets
├── Liabilities
└── Investments
        │
        ▼
DATA / REPOSITORIES
        │
        ▼
LOCAL DATABASE
```

---

# 33. Offline-First

Salapify should remain useful without a backend.

Prioritize:

- Local database
- Local calculations
- Local financial state
- Local forecasting
- Local insights
- Local document storage where practical

Future synchronization should be possible without rewriting the domain layer.

Avoid coupling the core financial engine directly to network services.

---

# 34. Privacy

Financial data is sensitive.

Design around:

- Local-first storage
- Minimal data collection
- Explicit permissions
- Transparent AI processing
- Secure document handling
- No unnecessary account creation
- No selling financial data
- User-controlled export
- User-controlled deletion

Privacy should be a product principle.

---

# 35. UX Principle

Do not expose the complexity of the financial system to the user unless necessary.

The system can be sophisticated underneath.

The interface should remain simple.

A good screen should ideally answer:

1. What matters?
2. Why does it matter?
3. What should I do?

Example:

```text
SAFE TO SPEND

₱6,850

You have 15 days until payday.

Upcoming obligations:
₱2,000

Goal contribution:
₱1,000

Recommended discretionary limit:
₱3,850

[View breakdown]
```

Use progressive disclosure.

Avoid information overload.

---

# 36. Product Differentiation

Do not compete feature-for-feature with global finance apps.

Borrow proven concepts.

Differentiate through:

### 1. Connected financial system

Not isolated tools.

### 2. Decision support

Not just reporting.

### 3. Forecasting

Not just historical analysis.

### 4. Philippine financial intelligence

Deep local relevance.

### 5. Scenario planning

Help users model possible futures.

### 6. Behavioral insights

Explain why financial patterns matter.

### 7. Privacy/offline-first

Strong trust proposition.

### 8. Pan

A contextual interface to the system.

---

# 37. Feature Prioritization

Prioritize using:

1. User value
2. Differentiation
3. Philippine relevance
4. Technical feasibility
5. Privacy
6. Long-term strategic value
7. Dependency on other systems

Do not prioritize based on feature count.

---

# 38. Suggested Roadmap

## P0 — Financial Foundation

Build the system foundation:

- Financial domain model
- Accounts
- Transactions
- Categories
- Income
- Bills
- Recurring transactions
- Budgets
- Goals
- Debt
- Credit cards
- Assets
- Liabilities
- Net worth
- Balance sheet
- Central financial calculation engine
- Financial state

---

## P1 — Core Intelligence

Build:

- Cash-flow forecast
- Safe-to-spend
- Payday budgeting
- Financial calendar
- Financial health
- Goal forecasting
- Debt calculations
- Credit-card intelligence
- Basic risk engine
- Basic insight engine

---

## P2 — Decision Support

Build:

- Can I afford this?
- What-if scenarios
- Purchase simulator
- Credit-card installment simulator
- Debt-versus-savings decisions
- Job-loss simulator
- Emergency mode
- Financial leakage
- Lifestyle inflation
- What Changed?
- Monthly financial autopsy

---

## P3 — Philippine Financial OS

Build:

- MP2 planner
- 13th-month planner
- Philippine holiday logic
- Family support
- OFW/remittance
- SSS
- PhilHealth
- Pag-IBIG
- HMO
- Local financial products

Implement these through a configurable country/rules layer.

---

## P4 — Advanced Intelligence

Build:

- Behavioral finance engine
- Life-event simulator
- Proactive insights
- Advanced Pan
- Financial document intelligence
- Benefits tracking
- Investment allocation visibility
- Inflation planning
- Financial independence
- Personalized financial action plans

---

# 39. What NOT to Prioritize

Do not build features simply because competitors have them.

Avoid prioritizing:

- Full bank aggregation before the core system is strong
- Brokerage functionality
- Full bill payment
- Insurance marketplace
- Excessive reports
- Dozens of charts
- Generic AI chatbot
- Generic financial tips
- Feature duplication
- Cosmetic features that do not improve the financial system

Do not become:

> "YNAB + AI + panda."

Salapify needs its own identity.

---

# 40. Feature Test

Before adding a feature, ask:

### User Problem

What financial problem does this solve?

### System Relationship

What financial entities does it interact with?

### Financial State

Does it change or inform the user's financial state?

### Prediction

Does it improve understanding of the future?

### Decision

Does it improve a financial decision?

### Action

Does it produce an actionable outcome?

### Reuse

Can it use the existing financial engine?

### Complexity

Does it create unnecessary complexity?

### Differentiation

Does it help Salapify become meaningfully different?

If a feature only produces another chart or another data-entry screen, challenge whether it belongs.

---

# 41. North-Star Experience

When a user opens Salapify, they should quickly understand:

## WHERE AM I?

Current financial position.

## WHAT'S NEXT?

Upcoming income and obligations.

## AM I OKAY?

Financial health and risks.

## WHAT CAN I SPEND?

Safe-to-spend.

## WHAT AM I WORKING TOWARD?

Goals and wealth.

## WHAT SHOULD I DO?

Next best action.

---

# 42. North-Star Metric Concept

The long-term product objective should be:

> **Help the user make a better financial decision in under 30 seconds.**

Potential future product metrics could measure:

- Insight engagement
- Recommended-action completion
- Goal progress
- Reduction in cash-flow shortfalls
- Debt reduction
- Savings consistency
- Financial-health improvement
- User retention around meaningful financial events

Do not optimize solely for:

- Number of transactions
- Number of screens
- Number of features
- Number of charts
- Number of AI messages

The goal is better financial outcomes and better decisions.

---

# 43. Final Product Thesis

The ambition is:

> **Build a system that continuously understands the user's financial state, predicts what may happen next, identifies financial risks and opportunities, and helps the user make better financial decisions.**

The app is the interface.

The financial engine is the foundation.

The intelligence layer is the differentiator.

Pan is the conversational interface.

The user's financial life is the system being managed.

---

# 44. Critical Instruction for Claude Code

We are building Salapify v3 from scratch.

**DO NOT immediately implement every feature in this document.**

First perform an architecture and product audit.

## Step 1 — Audit the repository

Analyze:

- Existing architecture
- Flutter structure
- Domain models
- Database
- State management
- Services
- Repositories
- UI
- Existing financial calculations
- Existing Pan architecture
- Design system
- Tests
- Existing dependencies
- Existing offline-first implementation

## Step 2 — Map the current product

Create a matrix:

```text
EXISTING FEATURE
       ↓
DOMAIN ENTITY
       ↓
CURRENT CAPABILITY
       ↓
DEPENDENCIES
       ↓
MISSING CAPABILITY
       ↓
FUTURE SYSTEM ROLE
```

## Step 3 — Identify architectural gaps

Specifically identify what would prevent Salapify from evolving into a Personal Financial Operating System.

Look for:

- Duplicated calculations
- Screen-driven architecture
- Weak domain boundaries
- Missing financial entities
- Tight UI/domain coupling
- Poor repository boundaries
- Missing use-case layer
- Hard-coded country assumptions
- Inconsistent financial calculations
- Missing test coverage
- State-management problems
- Offline-first limitations
- Future sync limitations

## Step 4 — Design the financial system

Propose:

- Core entities
- Relationships
- Financial state model
- Financial calculation engine
- Forecast engine
- Decision engine
- Risk engine
- Scenario engine
- Insight engine
- Recommendation engine
- Pan integration
- Country/rules layer

## Step 5 — Create a staged roadmap

Create:

- P0 Foundation
- P1 Core Intelligence
- P2 Decision Support
- P3 Philippine Financial OS
- P4 Advanced Intelligence

For every feature provide:

- User problem
- User value
- Competitive differentiation
- Philippine relevance
- Technical complexity
- Required domain models
- Dependencies
- Privacy considerations
- Offline-first considerations
- Future backend/sync considerations
- Recommended priority
- Whether it belongs in v3

## Step 6 — Identify what NOT to build

Explicitly identify features that would create:

- Feature bloat
- Technical debt
- Low user value
- Unnecessary complexity
- Poor differentiation

## Step 7 — Review before implementation

**Do not make large architectural changes yet.**

First provide:

1. Repository audit
2. Existing feature map
3. Architecture assessment
4. Proposed financial-system architecture
5. Domain model recommendations
6. P0–P4 roadmap
7. Recommended first implementation milestone
8. Risks and trade-offs

Wait for approval before making major implementation changes.

---

# 45. Final Guiding Question

Do not ask:

> "What feature should we add?"

Ask:

> **"What part of the user's financial life does Salapify not understand yet?"**

That question should guide Salapify v3.

The ambition is not to build the best budgeting screen.

The ambition is to build a **financial system that understands a person's money well enough to help them make better decisions.**
