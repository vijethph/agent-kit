---
applyTo: "**"
---

# Code Modification and Contribution Guidelines for AI Coding Agent

These instructions guide AI-assisted code contributions to ensure precision, maintainability, and alignment with project architecture. Follow each rule exactly unless explicitly told otherwise.

1. **Minimize Scope of Change**

   - Identify the smallest unit (function, class, or module) that fulfills the requirement.
   - Do not modify unrelated code.
   - Avoid refactoring unless required for correctness or explicitly requested.

2. **Preserve System Behavior**

   - Ensure the change does not affect existing features or alter outputs outside the intended scope.
   - Maintain original patterns, APIs, and architectural structure unless otherwise instructed.

3. **Graduated Change Strategy**

   - **Default:** Implement the minimal, focused change.
   - **If Needed:** Apply small, local refactorings (e.g., rename a variable, extract a function).
   - **Only if Explicitly Requested:** Perform broad restructuring across files or modules.

4. **Clarify Before Acting on Ambiguity**

   - If the task scope is unclear or may impact multiple components, stop and request clarification.
   - Never assume broader intent beyond the described requirement.

5. **Log, Don’t Implement, Unscoped Enhancements**

   - Identify and note related improvements without changing them.
   - Example: `// Note: Function Y may benefit from similar validation.`

6. **Ensure Reversibility**

   - Write changes so they can be easily undone.
   - Avoid cascading or tightly coupled edits.

7. **Code Quality Standards**

   - **Clarity:** Use descriptive names. Keep functions short and single-purpose.
   - **Consistency:** Match existing styles, patterns, and naming.
   - **Error Handling:** Use try/except (Python) or try/catch (JS/TS). Anticipate failures (e.g., I/O, user input).
   - **Security:** Sanitize inputs. Avoid hardcoding secrets. Use environment variables for config.
   - **Testability:** Enable unit testing. Prefer dependency injection over global state.
   - **Documentation:**
     - Use DocStrings (`"""Description"""`) for Python.
     - Use JSDoc (`/** @param {Type} name */`) for JavaScript/TypeScript.
     - Comment only non-obvious logic.

8. **Testing Requirements**

   - Add or modify only tests directly related to your change.
   - Ensure both success and failure paths are covered.
   - Do not delete existing tests unless explicitly allowed.

9. **Commit Message Format**

   - Use the [Conventional Commits](https://www.conventionalcommits.org) format.
   - Structure: `type(scope): message`, using imperative mood.
   - Examples:
     - `feat(auth): add login validation for expired tokens`
     - `fix(api): correct status code on error`
     - `test(utils): add tests for parseDate helper`

10. **Forbidden Actions Unless Explicitly Requested**

    - Global refactoring across files
    - Changes to unrelated modules
    - Modifying formatting or style-only elements without functional reason
    - Adding new dependencies

11. **Handling Ambiguous References**

    - When encountering ambiguous terms (e.g., "this component", "the helper"),
      always refer to the exact file path and line numbers when possible
    - If exact location is unclear, ask for clarification before proceeding
    - Never assume the meaning of ambiguous references

12. **Other Considerations**
    - No code comments unless it is really required. If there are code comments found in existing files, remove them unless they are absolutely necessary for understanding complex logic.
    - No emojis in any logging statements or code comments
    - Logging should be minimal, comprehensive, and should display full error stack traces when exceptions occur.
    - Do not generate too many markdown files.
    - All bash scripts should be under scripts folder only. They should be reusable for multiple purposes: local development, docker-compose setup and Kubernetes setup.
    - Use Minikube for kubernetes setup. Do not use kustomize for this project.

Always act within the described scope and prompt constraints. If unsure—ask first.

# Project-specific context and guidelines

we are a group of 4 students who are working on this group project. This group project requires a distributed system with 4 microservices connected to each other.

We have chosen the following topic for group project:
"""
Healthcare Patient Management System
A healthcare platform managing patient records, appointments, prescriptions, and billing with HIPAA compliance considerations.
"""

"COMP41720 - Group Project Rubric.txt" file contains the detailed rubric for this group project. FHIRIntegration.md file contains FHIR schemas and models to be used in this project. DraftImplementationPlan.md file contains the implementation plan drafted for this project. HealthcareSystemRoadmap.md contains the roadmap for this project.

We are implementing the project in this manner: local development with individual microservices running independently, build docker-compose to link them together, and then finally construct Kubernetes files with monitoring. We want to keep each service modular, simple, functional, running independently of each other, and then integrate all of them together. We are also considering the schemas such that they could be FHIR compatible so that we can easily integrate FHIR as an extension in the end of development.

We are using the following tech stack:
Programming Language: Python
Containerization: Docker and Kubernetes
Package Manager: pipenv
RestAPI framework: FastAPI
Logging: structlog
Retry framework: Tenacity
ORM: SQLAlchemy
Messaging: RabbitMQ with aio-pika
Linter and formatter: Pylint, Black
Testing: Pytest
Docstring format: reStructuredText

All packages being used are defined in Pipfile and Pipfile.lock files.

Docker images:

- Python: python:3.11-slim
- RabbitMQ: rabbitmq:4.0-management-alpine
- PostgreSQL: postgres:17-alpine
- Redis: redis:8-alpine
  Others: latest ones

We will be using the following technologies: Redis for caching, RabbitMQ for messaging, Prometheus for metrics and Grafana for dashboards.
We will not be using the following technologies: ELK stack for logging, email service, SMS service and Payment Gateway, as it would be too much complex for our application. We would not be using any other technologies unless it is really needed, as it would be too complex for our application, but we are open to small suggestions.

I am student 4, working on billing service on a separate branch from main. The billing service implementation plan has already been drafted in DraftImplementationPlan.md file, and the first and second parts have been implemented.

All schemas for all the models used in all the microservices in this project have been defined in FHIRIntegration.md file, and the architecture diagrams are in docs folder. Slight deviations from the models defined in FHIRIntegration.md file are tolerated, but FHIR compatibility is highly desired.

Refer GitHub repos, tutorials, YouTube videos, documentation, research papers and any form of online resources available.

# Personal Preferences

- I prefer using bash scripts to initialize databases and load data instead of Python scripts. These bash scripts should be reusable for multiple purposes: local development, docker-compose setup and Kubernetes setup.
- I prefer using Minikube for kubernetes setup, and I am not using kustomize for this project.
