# Book of Business

[![CI](https://github.com/sjnims/book_of_business/actions/workflows/ci.yml/badge.svg)](https://github.com/sjnims/book_of_business/actions/workflows/ci.yml)
[![CodeQL](https://github.com/sjnims/book_of_business/actions/workflows/codeql.yml/badge.svg)](https://github.com/sjnims/book_of_business/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/sjnims/book_of_business/graph/badge.svg?token=mzBScx1grB)](https://codecov.io/gh/sjnims/book_of_business)
[![Ruby](https://img.shields.io/badge/Ruby-3.4.4-red.svg)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/Rails-8.0.2-red.svg)](https://rubyonrails.org)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Security](https://img.shields.io/badge/Security-Brakeman%20%2B%20CodeQL-green.svg)](.github/SECURITY.md)

A Rails application for tracking sales contracts, services, and revenue calculations. Designed to replace Excel-based systems with a multi-user web application featuring complex MRR/ARR calculations, renewal tracking, and comprehensive reporting.

## Requirements

* Ruby 3.4.4
* PostgreSQL 14+

## Setup

```bash
# Clone the repository
git clone https://github.com/sjnims/book_of_business.git
cd book_of_business

# Install dependencies
bundle install

# Setup database
rails db:create
rails db:migrate
rails db:seed

# Install git hooks for code quality checks
rails hooks:install
# or: bin/setup-hooks

# Run tests
rails test

# Start the server
rails server
```

## Key Features

* **Multi-user authentication** with role-based access control
* **Order management** for tracking sales deals and contracts
* **Service tracking** with complex pricing and term calculations
* **Revenue calculations** including MRR, ARR, and GAAP metrics
* **Customer management** with potential accounting system integration
* **Comprehensive test coverage** (97.8% line coverage, 100% branch coverage)

## Technology

Built with Rails 8's modern stack:

* **Turbo** for seamless page navigation and form submissions
* **Stimulus** for JavaScript sprinkles without the complexity
* **Import Maps** for zero-build JavaScript
* **Propshaft** for simple asset management

## Development

See [ROADMAP.md](ROADMAP.md) for planned features and development phases.

### Code Quality

This project uses comprehensive automated pre-commit hooks to maintain enterprise-grade code quality:

#### Pre-commit Checks (Blocking)

* **Ruby Syntax Check** - Ensures all Ruby files are syntactically valid
* **RuboCop** - Enforces Ruby style guide and best practices
* **Security (Brakeman)** - Scans for security vulnerabilities
* **Database Schema** - Ensures migrations and schema.rb are in sync
* **Tests** - Runs relevant tests for modified files
* **FIXME/BUG Comments** - Blocks commits with unresolved issues
* **Large Files** - Prevents accidental commits of files >5MB
* **Credentials/Secrets** - Scans for hardcoded secrets

#### Pre-commit Warnings (Non-blocking)

* **Code Coverage** - Warns if coverage drops below 90%
* **Documentation** - Warns about missing class/method documentation
* **TODO Comments** - Tracks technical debt
* **ERB/HTML Syntax** - Basic template validation
* **Asset Compilation** - Verifies assets will compile

#### Pre-push Checks (Final Quality Gate)

The pre-push hook runs comprehensive checks on the entire codebase:

**Blocking Checks:**

* Full Ruby syntax validation across all files
* Complete RuboCop compliance check
* High-confidence security vulnerabilities (Brakeman)
* Full test suite execution
* Code coverage threshold (90% minimum)
* Database migration status
* Protected branch enforcement

**Warning Checks:**

* Code complexity metrics
* Medium-confidence security issues
* Dependency vulnerabilities
* Documentation coverage
* Conventional commit messages
* File permissions
* Outdated dependencies

To bypass hooks in an emergency: `git commit --no-verify` or `git push --no-verify` (NOT RECOMMENDED)

To run checks manually:

* Pre-commit: `rails hooks:check`
* Pre-push: `ruby .githooks/pre-push`

For optimal performance, pre-commit hooks run targeted tests while pre-push runs the full suite.

## License

Private repository - All rights reserved
