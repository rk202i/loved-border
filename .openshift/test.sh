#!/usr/bin/env bash
set -e

if [ ! -d ".openshift" ]; then
  warning "The script expects the .openshift directory to exist"
  exit 1
fi

source .openshift/openshift.sh

if [ -z "$1" ]; then
  ORG="openshift-vertx-examples"
else
  ORG=$1
fi

REPO="https://github.com/$ORG/vertx-cache-example-redhat"
echo -e "\n${YELLOW}Using source repository: $REPO ...\n${NC}"

# cleanup
oc delete build --all
oc delete bc --all
oc delete dc --all
oc delete deploy --all
oc delete is --all
oc delete istag --all
oc delete isimage --all
oc delete job --all
oc delete po --all
oc delete rc --all
oc delete rs --all
oc delete statefulsets --all
oc delete secrets --all
oc delete configmap --all
oc delete services --all
oc delete routes --all
oc delete template --all

# Deploy the templates and required resources
oc apply -f greeting-service/.openshift/service.cache.yml
oc apply -f cute-name-service/.openshift/application.yaml
oc apply -f greeting-service/.openshift/application.yaml

# Create the application
oc new-app --template=vertx-greeting-service \
    -p SOURCE_REPOSITORY_URL="$REPO" \
    -p SOURCE_REPOSITORY_DIR=greeting-service

oc new-app --template=vertx-cute-name-service \
    -p SOURCE_REPOSITORY_URL="$REPO" \
    -p SOURCE_REPOSITORY_DIR=cute-name-service

# wait for pods to be ready
waitForPodState "cache-server" "Running"
waitForPodReadiness "cache-server" 1
waitForPodState "cute-name-service" "Running"
waitForPodReadiness "cute-name-service" 1
waitForPodState "greeting-service" "Running"
waitForPodReadiness "greeting-service" 1

mvn clean install -DskipTests; cd integration-tests; mvn verify -Popenshift-it -Denv.init.enabled=false;
cd .. || exit
