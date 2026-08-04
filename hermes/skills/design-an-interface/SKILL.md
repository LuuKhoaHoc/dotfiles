---
name: design-an-interface
description: Turn a requirement into an explicit interface/API contract before implementation — inputs, outputs, errors, callers, and seams to test against. Use when user says "design the interface first", "API contract", "module boundary", "what should this module do", or before building a new feature/handler/service.
---

# Design An Interface

The requirement is already known. Improve it into an explicit interface/API contract before implementation.

## Goal

Move from "this exists" to "this receives this and returns that, here are the error cases, here is how callers use it."

## Analyzing inputs

If the requirement comes from a business flow document (.drawio, flowchart, swimlane diagram), read `references/flow-document-analysis.md` first — it covers mxGraph XML extraction and the workflow: flow → questions → code.

## Present this contract

- **Inputs**: shape, allowed ranges, defaults, invalid handling
- **Outputs**: success shape, error shape, optional/null behavior
- **Callers**: who calls it, what they assume, what they must not assume
- **Errors**: expected failure modes and how they surface
- **Seams**: where tests would attach; prefer an existing seam if one exists
- **Dependencies**: what it reaches into, why it can't avoid it

## After presenting

Ask the user for feedback on:

- Is any input/output missing or wrong?
- Is the seam testable in the repo's existing setup?
- What is the minimal behavioral contract this interface must preserve?

Once the contract is accepted, implementation is sheriffed by `/implement-plan` or the project's standard workflow.
