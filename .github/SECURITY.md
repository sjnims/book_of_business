# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| develop | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: <sjnims@gmail.com>

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

Please include the requested information listed below (as much as you can provide) to help us better understand the nature and scope of the possible issue:

* Type of issue (e.g. buffer overflow, SQL injection, cross-site scripting, etc.)
* Full paths of source file(s) related to the manifestation of the issue
* The location of the affected source code (tag/branch/commit or direct URL)
* Any special configuration required to reproduce the issue
* Step-by-step instructions to reproduce the issue
* Proof-of-concept or exploit code (if possible)
* Impact of the issue, including how an attacker might exploit the issue

This information will help us triage your report more quickly.

## Preferred Languages

We prefer all communications to be in English.

## Policy

We follow the principle of [Coordinated Vulnerability Disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure).

## Security Tools and Automated Scanning

This project employs multiple layers of automated security analysis:

### 1. Brakeman (Rails Security Scanner)

* **Runs on**: Every push and pull request
* **Purpose**: Rails-specific vulnerability detection
* **Coverage**: SQL injection, XSS, mass assignment, CSRF, and more
* **Configuration**: See `bin/brakeman` for options

### 2. CodeQL (Semantic Code Analysis)

* **Runs on**: Push to main/develop, PRs, and weekly schedule
* **Purpose**: Deep semantic analysis for complex security patterns
* **Languages**: Ruby and JavaScript/TypeScript
* **Custom Queries**: Rails-specific patterns in `.github/codeql/`
  * `rails-security.qls`: Enterprise security query suite
  * `custom-queries.ql`: Custom Rails vulnerability patterns
* **Features**:
  * Extended security queries including experimental patterns
  * High and medium precision vulnerability detection
  * Automated PR comments for security findings
  * SARIF reports uploaded as artifacts

### 3. Additional Security Measures

* **bundler-audit**: Checks for known vulnerabilities in gem dependencies
* **TruffleHog**: Scans for accidentally committed secrets
* **Custom grep patterns**: Quick detection of common anti-patterns
* **ESLint security plugin**: JavaScript security analysis (when JS is added)

## Security Best Practices for Contributors

### Code Guidelines

1. **Never commit secrets**: Use Rails credentials or environment variables
2. **Strong parameters**: Always use `permit()` in controllers
3. **Input validation**: Validate and sanitize all user input
4. **SQL safety**: Use parameterized queries, never string interpolation
5. **Authentication**: Use `before_action :require_login` consistently
6. **Authorization**: Implement role-based access controls
7. **Logging**: Log security events but never log sensitive data

### Pre-commit Checklist

* [ ] Run `bin/brakeman` locally before committing
* [ ] Run `bundle audit check --update` to check dependencies
* [ ] Review changes for hardcoded secrets
* [ ] Ensure all new endpoints have authentication
* [ ] Verify params are properly permitted
* [ ] Check that error messages don't leak sensitive info

### Security Headers

The application enforces these headers (configured in `config/initializers/content_security_policy.rb`):

* `X-Frame-Options: DENY`
* `X-Content-Type-Options: nosniff`
* `X-XSS-Protection: 1; mode=block`
* `Strict-Transport-Security` (in production)
* `Content-Security-Policy` with strict directives

## Regular Security Tasks

* **Every commit**: Brakeman and basic security checks

* **Every PR**: CodeQL analysis with custom Rails queries
* **Weekly**: Deep CodeQL security analysis
* **Monthly**: Dependency updates and security patches

## Compliance Considerations

This application is designed with security controls to support:

* SOC 2 Type II compliance
* GDPR data protection requirements
* HIPAA-ready architecture (with additional configuration)
* PCI DSS guidelines for payment data (when applicable)
