/**
 * @name Rails unsafe parameter usage
 * @description Detects potentially unsafe usage of params in Rails controllers
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @id ruby/unsafe-params-usage
 * @tags security
 *       external/cwe/cwe-915
 *       rails
 */

import ruby

from MethodCall mc, Method m
where
  mc.getMethodName() = "params" and
  not exists(MethodCall permit |
    permit.getMethodName() = "permit" and
    permit.getReceiver() = mc
  ) and
  exists(Assignment a | a.getRhs() = mc)
select mc, "Direct params usage without permit() may lead to mass assignment vulnerabilities"

---

/**
 * @name Hardcoded secrets in Rails
 * @description Detects hardcoded secrets in Rails configuration
 * @kind problem
 * @problem.severity error
 * @precision high
 * @id ruby/hardcoded-secrets
 * @tags security
 *       external/cwe/cwe-798
 */

import ruby

from StringLiteral s, Assignment a
where
  a.getRhs() = s and
  (
    a.getLhs().toString().matches("%secret%") or
    a.getLhs().toString().matches("%password%") or
    a.getLhs().toString().matches("%token%") or
    a.getLhs().toString().matches("%key%")
  ) and
  s.getValue().length() > 8 and
  not s.getValue() = "change_me" and
  not s.getValue() = "password" and
  not s.getValue() = "secret"
select s, "Potential hardcoded secret found. Use Rails credentials or environment variables instead."