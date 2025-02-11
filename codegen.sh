#!/bin/sh

echo "Generating code from GraphQL schema"
npx aws-appsync-codegen generate schema/**/*.graphql --schema schema/schema.json --target swift --output SudoAdTrackerBlocker/API.swift

echo "Generating schema.graqhql file"
npx aws-appsync-codegen print-schema schema/schema.json --output schema/schema.graphql

# GraphQL codegen creates all functions/objects as public. Only only at the moment to change this is to 
# post process the file using sed to replace with internal.
sed -i "" 's/[[:<:]]public[[:>:]]/internal/g' SudoAdTrackerBlocker/API.swift
