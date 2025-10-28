# Contributing to DockerKit

Thank you for your interest in contributing to DockerKit! This document provides guidelines for contributing to the project.

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and changelog generation.

### Commit Format

```text
<type>(scope): <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type       | Description                  | Release Impact                |
|------------|------------------------------|-------------------------------|
| `feat`     | New features                 | Minor release (1.0.0 → 1.1.0) |
| `fix`      | Bug fixes                    | Patch release (1.0.0 → 1.0.1) |
| `perf`     | Performance improvements     | No release                    |
| `refactor` | Code refactoring             | No release                    |
| `docs`     | Documentation changes        | No release                    |
| `style`    | Code style changes           | No release                    |
| `test`     | Test additions/modifications | No release                    |
| `chore`    | Maintenance tasks            | No release                    |
| `ci`       | CI/CD changes                | No release                    |

### Scopes for DockerKit

| Scope       | Description                            |
|-------------|----------------------------------------|
| `docker`    | Docker configuration and compose files |
| `nginx`     | Nginx server configuration             |
| `workspace` | PHP workspace container                |
| `mysql`     | MySQL database configuration           |
| `postgres`  | PostgreSQL database configuration      |
| `ssl`       | SSL certificates and HTTPS setup       |
| `tools`     | Scripts and utility tools              |
| `project`   | Project-wide changes                   |

### Message Length Requirements

To maintain consistency and readability:

- **Header** (first line): Maximum 100 characters
- **Body lines**: Maximum 100 characters per line
- **Footer**: No length restrictions

### Examples

```bash
# New features
feat(nginx): add HTTP/3 support
feat(workspace): add Node.js 22 support
feat(ssl): implement automatic certificate renewal

# Bug fixes
fix(mysql): resolve character encoding issue
fix(workspace): fix PHP extension installation
fix(tools): correct SSL generation script

# Performance improvements
perf(nginx): optimize gzip compression settings
perf(docker): reduce image build time

# Documentation
docs(readme): update installation instructions
docs(api): add new endpoint documentation

# Refactoring
refactor(tools): simplify SSL certificate generation
refactor(nginx): reorganize configuration structure

# Breaking changes
feat(docker)!: migrate to Docker Compose v2

BREAKING CHANGE: Docker Compose v1 is no longer supported.
Users must upgrade to Docker Compose v2 to use this version.

# Proper body formatting (max 100 chars per line)
ci: add Docker Build Checks workflow

- Introduced `.github/workflows/docker-build-checks.yml` for automated
  Docker build validation and docker-compose linting.
- Refined `nginx/Dockerfile` and `workspace/Dockerfile` with OCI standard
  labels for metadata and improved maintainability.
- Added `check-dockerfiles` and `lint` targets in `Makefile` to facilitate
  quality assurance tasks.

feat: add project setup and maintenance targets

- Add `reset`, `check-env`, and `create-logs-dir` targets to improve
  project setup and maintenance workflow.
```

### AI Assistant Prompt

For users of PhpStorm's AI Assistant, you can use the following prompt to generate commit messages that adhere to our conventions. This helps ensure consistency and leverages AI to speed up your workflow.

```text
Generate a commit message for the given code changes.

Strictly adhere to the following rules based on the project's contributing guidelines:

1.  Format: The commit message must follow the Conventional Commits specification.
    - The format is: `<type>(scope): <description>`
    - The header (first line) must not exceed 100 characters.
    - Each line of the optional body must be wrapped at 100 characters.

2.  Type: The `<type>` must be one of the following, based on the nature of the changes:
    - `feat`: A new feature for the user.
    - `fix`: A bug fix for the user.
    - `perf`: A code change that improves performance.
    - `refactor`: A code change that neither fixes a bug nor adds a feature.
    - `docs`: Documentation-only changes.
    - `style`: Changes that do not affect the meaning of the code (white-space, formatting, etc).
    - `test`: Adding missing tests or correcting existing tests.
    - `chore`: Changes to the build process or auxiliary tools and libraries.
    - `ci`: Changes to CI configuration files and scripts.

3.  Scope: The `<scope>` must be one of the following, reflecting the area of the codebase that was changed. Choose the most relevant one.
    - `docker`: Docker configuration, Dockerfiles, or compose files.
    - `nginx`: Nginx server configuration.
    - `workspace`: The PHP workspace container.
    - `mysql`: MySQL database configuration.
    - `postgres`: PostgreSQL database configuration.
    - `ssl`: SSL certificates and HTTPS setup.
    - `tools`: Scripts and utility tools.
    - `project`: Project-wide changes or when multiple scopes are affected.

4.  Description: Write a short, imperative summary of the code changes. Start with a lowercase letter and do not end with a period.

5.  Body:
    - If the change is complex, add an optional body after the header, separated by a blank line.
    - Explain the "what" and "why" of the change, not the "how".
    - Use bullet points for lists if it improves readability.

6.  Breaking Changes:
    - If the commit introduces a breaking change, append `!` after the `type(scope)`.
    - Add a footer starting with `BREAKING CHANGE:` on a new line after the body, explaining the breaking change and what users need to do.

Analyze the provided diff and output only the raw commit message text without any introductory phrases.
```

## Release Process

Our releases are fully automated using [semantic-release](https://github.com/semantic-release/semantic-release):

1. **Push commits** to `main` branch with conventional commit messages
2. **GitHub Actions** automatically analyzes commit messages
3. **Determines release type** (patch/minor/major) based on commit types
4. **Creates Git tag** with new version number
5. **Generates CHANGELOG.md** with grouped changes
6. **Creates GitHub Release** with release notes
7. **Updates version** in package.json

### Release Types

- **Patch** (1.0.0 → 1.0.1): Only `fix` commits
- **Minor** (1.0.0 → 1.1.0): Contains `feat` commits
- **Major** (1.0.0 → 2.0.0): Contains breaking changes (`feat!`, `fix!`, or `BREAKING CHANGE:`)

## Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/add-redis-support
```

### 2. Make Changes

Develop your feature following the project structure and coding standards.

### 3. Commit Changes

Use conventional commit messages:

```bash
git commit -m "feat(cache): add Redis support for session storage"
```

### 4. Push Branch

```bash
git push origin feature/add-redis-support
```

### 5. Create Pull Request

- Create PR to `main` branch
- Ensure all checks pass
- Request review from maintainers

### 6. Merge and Release

- After PR is merged to `main`
- Automatic release will be triggered
- New version will be published

## Pull Request Guidelines

### PR Title

Use conventional commit format for PR titles:

```text
feat(nginx): add rate limiting support
```

### PR Description

Include:

- Clear description of changes
- Type of change (feature, bugfix, etc.)
- Breaking changes (if any)
- Testing instructions

### PR Checklist

- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] Changes are documented (if needed)
- [ ] All existing functionality works
- [ ] New features include appropriate documentation

## Bug Reports

When reporting bugs, please include:

- DockerKit version
- Docker version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Error messages or logs

## Feature Requests

For feature requests, please describe:

- Use case and motivation
- Proposed solution
- Alternative solutions considered
- Additional context

## Getting Help

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Documentation**: Check README.md and project documentation

## CI/CD

DockerKit includes comprehensive automated quality checks:

| Check                     | Tool                                                                                     | Purpose                                   |
|---------------------------|------------------------------------------------------------------------------------------|-------------------------------------------|
| **Docker Best Practices** | [Docker Build Checks](https://github.com/marketplace/actions/docker-setup-buildx)        | Dockerfile linting                        |
| **Dockerfile Linting**    | [Hadolint](https://github.com/marketplace/actions/hadolint-action)                       | Advanced Dockerfile static analysis       |
| **Shell Scripts**         | [ShellCheck](https://github.com/marketplace/actions/shellcheck)                          | Shell script static analysis              |
| **Markdown**              | [markdownlint-cli2](https://github.com/marketplace/actions/markdownlint-cli2-action)     | Markdown formatting and style consistency |
| **Links**                 | [Lychee](https://github.com/marketplace/actions/lychee-broken-link-checker)              | Broken link detection in documentation    |
| **Environment Files**     | [dotenv-linter](https://github.com/marketplace/actions/run-dotenv-linter-with-reviewdog) | .env file validation and security checks  |

All checks run automatically on pull requests.

Thank you for contributing to DockerKit!
