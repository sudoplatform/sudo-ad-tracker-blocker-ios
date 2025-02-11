# Sudo Ad/Tracker Blocker SDK for iOS

## Project setup

Clone this repo.

Install depenencies with swift package manager

## Running integration tests

To run the integration tests,

1. Obtain AWS credentials to download the client config from AWS parameter store.
2. Run the following command to download the client config into the project directory.

`sh download_config.sh -c <tenant_name>`

3. Select `AdTrackerBlockerIntegrationTests` build schema and run all enabled tests.

## Running unit tests 

1. Select `AdTrackerBlocker` build schema and run all enabled tests.

## Regenerating GraphQL API code

The GraphQL query definitions are maintained in `schema/operations.graphql`.

To regenerate `API.swift` from the query definitions and locally cached API introspection schema,

1. Ensure node.js and `npm` are installed on your system.
2. Run `sh codegen.sh`

To obtain the latest API introspection schema,

1. Follow the above steps to obtain AWS credentials and download the client config into the project directory.
2. Run `sh download_schema.sh`.

To speed up schema regeneration, consider running `npm install --global aws-appsync-codegen` to install the codegen utility globally on your system.

## Publishing

1. Ensure the `CHANGELOG.md` file and podspec are updated for the release.
2. Create a new tag on GitLab.
3. In the release notes, copy the relevant changes from `CHANGELOG.md`.
4. Run the "publish" stage of the resulting pipeline for the tag.

## Consumption

Add to repo to your apps package.

## Sonarqube

This project uses Sonarqube to analyze merge requests.

See the output of Sonarqube pipeline stages for more information and analysis results.

## SwiftLint

This project has customized source code linting rules using [SwiftLint](https://github.com/realm/SwiftLint).

To lint the project, run `brew install swiftlint` then run `swiftlint` from the project directory.

## Jazzy

This project supports using [Jazzy](https://github.com/realm/jazzy) to generate API reference documentation.

To generate documentation, run `bundle install && bundle exec jazzy` from the project directory.
