---
name: onboard
description: "Generate a project onboarding guide — architecture overview, key patterns, development workflow, and getting started steps. Activate when #ob appears anywhere in the user message."
argument-hint: "[focus-area]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Task
---

Generate onboarding guide for: $ARGUMENTS

Phase 1 — Repository analysis:

1. Run `repo-radar` to get the repository structure and tech stack.
2. Read `.claude/state/memory/` if it exists for accumulated project knowledge.
3. Scan for README, CONTRIBUTING, package.json, Makefile, docker-compose, CI config.
4. Identify the primary language, framework, and build system.

Phase 2 — Architecture mapping:

1. Use `repo-librarian` to identify:
   - Entry points (main files, index files, server bootstrap)
   - Key directories and their purposes
   - Configuration files and environment setup
   - Database or external service dependencies
2. Map the data flow for 2-3 core features.

Phase 3 — Development workflow:

1. Identify how to:
   - Install dependencies
   - Run the development server
   - Run tests
   - Build for production
   - Deploy (if CI/CD is configured)
2. Document environment variables and required tools.

Phase 4 — Generate guide:

```
Project Onboarding Guide
========================

## Overview
[1-2 paragraphs about what this project does]

## Tech Stack
[Language, framework, key libraries]

## Architecture
[Directory structure with purposes]
[Key patterns used]

## Getting Started
1. [Step-by-step setup instructions]

## Development Workflow
[How to run, test, build, deploy]

## Key Files
[Most important files a new developer should read first]

## Conventions
[Coding standards, naming conventions, commit style]
```
