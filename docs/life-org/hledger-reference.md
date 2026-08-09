# hledger Quick Reference

## Basic Commands

### Balance
```bash
# Show all account balances
hledger -f journal.journal balance

# Show assets and liabilities only
hledger -f journal.journal balance assets liabilities

# Show expenses by category (depth 2)
hledger -f journal.journal balance expenses --depth 2

# Monthly summary
hledger -f journal.journal balance --monthly --depth 2

# Yearly summary
hledger -f journal.journal balance --yearly
```

### Register
```bash
# Show all transactions
hledger -f journal.journal register

# Filter by account
hledger -f journal.journal register expenses:food

# Filter by date range
hledger -f journal.journal register date:2024-01-01..2024-12-31

# Filter by description
hledger -f journal.journal register desc:"grocery"
```

### Custom Reports
```bash
# Income statement
hledger -f journal.journal incomestatement

# Balance sheet
hledger -f journal.journal balancesheet

# Cash flow
hledger -f journal.journal cashflow

# Statistics
hledger -f journal.journal stats
```

## Journal Format

```
2024-01-15 Grocery Store
    expenses:food:groceries    $50.00
    assets:checking

2024-01-16 Salary
    assets:checking            $3000.00
    income:salary

2024-01-20 Rent
    expenses:housing:rent      $1200.00
    assets:checking
```

## Common Queries for Agents

- "What did I spend on food this month?"
  `hledger -f journal.journal balance expenses:food --begin thismonth`

- "What's my net worth?"
  `hledger -f journal.journal balancesheet`

- "Show me last 10 transactions"
  `hledger -f journal.journal register | tail -10`

- "How much did I earn vs spend this year?"
  `hledger -f journal.journal incomestatement --begin thisyear`