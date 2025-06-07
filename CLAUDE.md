# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Book of Business is a Rails 8.0.2 application designed to replace an Excel-based system for tracking transactional contracts data, sales deals, renewals, and revenue calculations.

## Technology Stack

- **Ruby on Rails**: 8.0.2
- **Database**: PostgreSQL with Solid Cache, Solid Queue, and Solid Cable
- **CSS**: Plain CSS (via Propshaft)
- **JavaScript**: Import Maps with Turbo & Stimulus (Hotwire)
- **Testing**: Minitest with minitest-reporters
- **Background Jobs**: Solid Queue
- **WebSockets**: Solid Cable
- **Asset Pipeline**: Propshaft
- **Frontend**: Turbo for navigation/forms, Stimulus for interactivity

## Key Business Requirements

### Core Entities

- **Orders**: Track sales deals with order numbers, sold dates, and total contract value (TCV)
- **Customers**: Store customer information with potential integration to accounting systems
- **Services**: Manage individual services within orders, including pricing, terms, and status
- **Revenue Calculations**: Handle complex MRR, ARR, GAAP MRR calculations with annual escalators

### Important Date Field Distinctions

- **Order Dates**:
  - `sold_date`: The date when the order was closed/won (for sales reporting)

- **Service Dates** (each service can have different dates):
  - `billing_start_date`: When customer billing begins for this service
  - `billing_end_date`: When customer billing ends (typically start date + term months - 1 day)
  - `rev_rec_start_date`: When revenue recognition begins (may differ from billing)
  - `rev_rec_end_date`: When revenue recognition ends
  
- **Key Concepts**:
  - NRCs = Non-Recurring Charges (one-time fees)
  - Billing and revenue recognition dates are usually the same but can differ
  - Each service within an order tracks its own dates independently

### Critical Features

- Multi-user concurrent access (replacing single-user Excel limitation)
- Complex revenue calculations including escalators and term variations
- Audit trails for all changes
- Renewal/upgrade/downgrade tracking with net-new calculations
- Comprehensive reporting (Rent Roll, BBNB, Churn, Renewals)
- Excel import/export capabilities

## Development Commands

```bash
# Install dependencies
bundle install

# Setup database
rails db:create
rails db:migrate

# Run the server
rails server

# Run tests
rails test

# Run console
rails console

# Run linter
bundle exec rubocop
```

## Database Configuration

The application uses PostgreSQL with multiple databases:

- Primary database for main application data
- Separate databases for Solid Cable, Cache, and Queue in production
- Single database with separate tables in development

## Testing Strategy

- Uses Minitest (not RSpec) as the testing framework
- minitest-reporters gem for enhanced test output
- System tests with Capybara and Selenium WebDriver
- Follow Rails testing conventions
- Code coverage tracking with Codecov.io (integration pending)

## Security Considerations

- Authentication: Use Rails built-in authentication (NOT Devise)
- Role-based access control required
- Audit logging for all data changes (custom implementation needed)
- Data encryption at rest and in transit
- Secure API endpoints for integrations

## Business Logic Notes

### Revenue Calculations

- TCV Formula: FV(Annuity Due) = C × [(1+i)^n - 1 / i] × (1+i) + NRCs
  - Where NRCs = Non-Recurring Charges (stored in `services.nrcs`)
- GAAP MRR = (TCV - NRCs) / contract term in months
- Handle complex renewal scenarios with pro-rating
- Revenue calculations use the service's `rev_rec_start_date` and `rev_rec_end_date`

### Service Status Workflow

- Pending Installation → Active → Extended/Renewed/Canceled
- Track original orders for renewal chains

## Architecture Guidelines

- Follow Rails conventions
- Use concerns for shared model behavior (auditing, calculations)
- Service objects for complex business logic
- API-first design for integrations
- Modular architecture for future enhancements
- Custom audit trail system (likely using ActiveRecord callbacks and a dedicated audit table)

## Performance Requirements

- Must handle large datasets efficiently
- Support concurrent multi-user access
- Fast report generation
- Optimized queries for complex calculations

## Future Considerations

- AI/ML for predictive analytics
- Mobile application support
- Advanced workflow automation
- Integration with CRM/ERP systems

## Development Preferences

- Authentication: Rails built-in (has_secure_password), NOT Devise
- Audit Trail: Custom implementation, NOT paper_trail or audited gems
- Code Coverage: Codecov.io for tracking test coverage
- Documentation: Use RDoc style comments (Ruby standard), NOT Google-style docstrings
- Keep it simple - avoid unnecessary gems when Rails provides the functionality
- Frontend: Use Turbo/Stimulus (Hotwire) for dynamic behavior, avoid heavy JavaScript frameworks
- Prefer server-side rendering with Turbo enhancements over SPA patterns

## Chat Preferences

- Explain context for changes
- Use friendly tone
