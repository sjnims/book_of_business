# Book of Business

[![CI](https://github.com/sjnims/book_of_business/actions/workflows/ci.yml/badge.svg)](https://github.com/sjnims/book_of_business/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/sjnims/book_of_business/graph/badge.svg?token=mzBScx1grB)](https://codecov.io/gh/sjnims/book_of_business)
[![Ruby](https://img.shields.io/badge/Ruby-3.4.4-red.svg)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/Rails-8.0.2-red.svg)](https://rubyonrails.org)

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

## License

Private repository - All rights reserved
