# [Ecosyste.ms: dependabot](https://dependabot.ecosyste.ms)

An open index of Dependabot pull requests and security advisories across open source projects, providing insights into dependency update patterns and security vulnerability management.

## What is this?

This service tracks and analyzes Dependabot pull requests across GitHub repositories, helping package maintainers, security researchers, and developers understand:

- **Dependency Update Patterns**: Which packages are being updated most frequently, what types of updates are common (major, minor, patch), and which repositories are keeping their dependencies current
- **Security Advisory Coverage**: Which security vulnerabilities are being addressed by Dependabot PRs, tracking the relationship between published advisories (CVEs, GHSAs) and automated dependency updates
- **Ecosystem Health**: Adoption patterns of dependency management across different programming language ecosystems

## Who is this useful for?

### Package Maintainers
- **Track downstream adoption**: See which repositories are receiving Dependabot PRs for your packages
- **Monitor update patterns**: Understand how quickly the community adopts new versions of your packages
- **Security impact assessment**: Identify which security advisories affect your packages and track remediation

### Security Researchers
- **Vulnerability landscape**: Analyze how security advisories propagate through the open source ecosystem
- **Response time analysis**: Study how quickly vulnerabilities are addressed through automated dependency updates
- **Impact assessment**: Understand the blast radius of security vulnerabilities across projects

### DevOps & Security Teams
- **Dependency intelligence**: Research packages before adoption by understanding their update frequency and security history
- **Benchmark practices**: Compare your dependency management practices against similar projects
- **Supply chain insights**: Track security advisories and their resolution across your technology stack

## Key Features

- **Package Search**: Find packages and explore their Dependabot activity across repositories
- **Security Advisory Tracking**: Browse security advisories and see which Dependabot PRs address them
- **Analytics**: View trends in dependency updates, merge rates, and security response times
- **Cross-references**: Link between packages, repositories, issues, and security advisories
- **REST API**: Programmatic access to all data for integration with your tools
- **RSS Feeds**: Subscribe to real-time updates for specific packages, repositories, or global activity

This project is part of [Ecosyste.ms](https://ecosyste.ms), tools and open datasets to support, sustain, and secure critical digital infrastructure.

## API

Documentation for the REST API is available here: [https://dependabot.ecosyste.ms/docs](https://dependabot.ecosyste.ms/docs)

The default rate limit for the API is 5000/req per hour based on your IP address, get in contact if you need to to increase your rate limit.

## Development

For development and deployment documentation, check out [DEVELOPMENT.md](DEVELOPMENT.md)

## Contribute

Please do! The source code is hosted at [GitHub](https://github.com/ecosyste-ms/dependabot). If you want something, [open an issue](https://github.com/ecosyste-ms/dependabot/issues/new) or a pull request.

If you need want to contribute but don't know where to start, take a look at the issues tagged as ["Help Wanted"](https://github.com/ecosyste-ms/dependabot/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22).

You can also help triage dependabot. This can include reproducing bug reports, or asking for vital information such as version numbers or reproduction instructions. 

Finally, this is an open source project. If you would like to become a maintainer, we will consider adding you if you contribute frequently to the project. Feel free to ask.

For other updates, follow the project on Twitter: [@ecosyste_ms](https://twitter.com/ecosyste_ms).

### Note on Patches/Pull Requests

 * Fork the project.
 * Make your feature addition or bug fix.
 * Add tests for it. This is important so we don't break it in a future version unintentionally.
 * Send a pull request. Bonus points for topic branches.

### Vulnerability disclosure

We support and encourage security research on Ecosyste.ms under the terms of our [vulnerability disclosure policy](https://github.com/ecosyste-ms/dependabot/security/policy).

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](https://github.com/ecosyste-ms/.github/blob/main/CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## Copyright

Code is licensed under [GNU Affero License](LICENSE) © 2023 [Andrew Nesbitt](https://github.com/andrew).

Data from the API is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
