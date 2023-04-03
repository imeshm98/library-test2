#!/bin/bash

# Set variables
LIB_NAME="myapp-repo-new"
BUCKET_NAME="myapp-repo-new"
RELEASE_FOLDER="releases"
SNAPSHOT_FOLDER="snapshots"
RELEASE_TYPE=$1

# Get the current version from the POM file
CURRENT_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)

# Get version to an array
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR_VERSION=${VERSION_PARTS[0]}
MINOR_VERSION=${VERSION_PARTS[1]}
PATCH_VERSION=${VERSION_PARTS[2]}

# Check the release type and increase the version
if [ "$RELEASE_TYPE" == "patch" ]; then
    NEW_VERSION="$MAJOR_VERSION.$MINOR_VERSION.$((PATCH_VERSION + 1))"
elif [ "$RELEASE_TYPE" == "minor" ]; then
    NEW_VERSION="$MAJOR_VERSION.$((MINOR_VERSION + 1)).0"
elif [ "$RELEASE_TYPE" == "major" ]; then
    NEW_VERSION="$((MAJOR_VERSION + 1)).0.0"
else 
    echo "Invalid input..."
    exit 1
fi

# Check user working on main branch or not
BRANCH_NAME=$(git branch --show-current)
if [ "$BRANCH_NAME" != "main" ]; then
    echo "You can only push changes from the 'main' branch. Switch to the 'main' branch"
    exit 1
fi

# Replace the version in the POM file with the new release version
# sed -i 's|^\(\s*\)<version>'"$CURRENT_VERSION"'-SNAPSHOT</version>$|\1<version>'"$NEW_VERSION"'</version>|' pom.xml
mvn versions:set -DnewVersion=$NEW_VERSION

# Deploy the release JAR to S3
mvn deploy -DaltDeploymentRepository="s3-repo::default::s3://${BUCKET_NAME}/${RELEASE_FOLDER}"

# Replace the version in the POM file with the new snapshot version
# sed -i 's|^\(\s*\)<version>'"$NEW_VERSION'</version>$|\1<version>'"$NEW_VERSION-SNAPSHOT"'</version>|' pom.xml
mvn versions:set -DnewVersion="$NEW_VERSION-SNAPSHOT"

# Deploy the snapshot JAR to S3
mvn deploy -DaltDeploymentRepository="s3-repo::default::s3://${BUCKET_NAME}/${SNAPSHOT_FOLDER}"

# Commit and push changes to GitHub main branch only
git add .
git commit -m "Released new version"
git push origin main
git tag $NEW_VERSION
git push origin $NEW_VERSION