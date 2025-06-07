# CodeQL Security Analysis Configuration

This directory contains custom CodeQL configurations for enhanced security analysis of our Rails application.

## Files

### `codeql-config.yml`

Main configuration file that defines:

- Paths to analyze and ignore
- Query filters for security and quality
- Performance settings
- Feature flags for advanced analysis

### `rails-security.qls`

Query suite specifically for Rails security patterns including:

- SQL injection detection
- XSS vulnerabilities
- CSRF protection gaps
- Mass assignment issues
- Authentication/authorization flaws
- Cryptographic weaknesses
- Path traversal vulnerabilities

### `custom-queries.ql`

Custom CodeQL queries for Rails-specific patterns:

1. **Unsafe parameter usage**: Detects `params` usage without `permit()`
2. **Hardcoded secrets**: Finds potential secrets in code

## Adding New Queries

To add a new security query:

1. Create a new `.ql` file in this directory
2. Follow the CodeQL query format:

   ```ql
   /**
    * @name Query name
    * @description What this query detects
    * @kind problem
    * @problem.severity error|warning|recommendation
    * @precision very-high|high|medium|low
    * @id ruby/unique-query-id
    * @tags security
    *       external/cwe/cwe-xxx
    */
   ```

3. Add the query to `rails-security.qls` if it should run by default

## Testing Queries Locally

To test CodeQL queries locally:

```bash
# Install CodeQL CLI
brew install codeql

# Download CodeQL database for Ruby
codeql database create ruby-db --language=ruby

# Run a specific query
codeql query run .github/codeql/custom-queries.ql --database=ruby-db

# Run the full suite
codeql analyze ruby-db .github/codeql/rails-security.qls --format=sarif-latest --output=results.sarif
```

## Query Performance

- Queries timeout after 300 seconds
- 7GB RAM allocated for analysis
- 4 threads for parallel processing

Optimize queries by:

- Using specific predicates instead of wildcards
- Limiting the scope with `where` clauses
- Avoiding expensive joins when possible

## Resources

- [CodeQL documentation](https://codeql.github.com/docs/)
- [CodeQL query examples](https://github.com/github/codeql)
- [Ruby CodeQL queries](https://github.com/github/codeql/tree/main/ruby/ql/src)
- [Writing CodeQL queries](https://codeql.github.com/docs/writing-codeql-queries/)
