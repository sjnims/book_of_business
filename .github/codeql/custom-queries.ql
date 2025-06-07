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
import codeql.ruby.dataflow.DataFlow

from AssignExpr ae, StringLiteral str
where
  ae.getRightOperand() = str and
  (
    ae.getLeftOperand().toString().toLowerCase().matches("%secret%") or
    ae.getLeftOperand().toString().toLowerCase().matches("%password%") or
    ae.getLeftOperand().toString().toLowerCase().matches("%token%") or
    ae.getLeftOperand().toString().toLowerCase().matches("%key%") or
    ae.getLeftOperand().toString().toLowerCase().matches("%api%")
  ) and
  str.getConstantValue().toString().length() > 6 and
  not str.getConstantValue().toString() = "change_me" and
  not str.getConstantValue().toString() = "password" and
  not str.getConstantValue().toString() = "secret" and
  not str.getConstantValue().toString() = "your_secret_key_here"
select ae, "Potential hardcoded secret: " + ae.getLeftOperand().toString() + ". Use Rails credentials or environment variables instead."