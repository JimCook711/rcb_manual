#!/bin/bash
# This script automates the creation and setup of a Revenue Cloud scratch org.
# It uses a user-defined multi-step deployment process for maximum control.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
TIMESTAMP=$(date +%m%d_%H%M)
ORG_ALIAS="rcbScratch_$TIMESTAMP"
SCRATCH_DEF_FILE="config/dev-scratch-def.json"
PERM_LICENSE_SCRIPT="scripts/apex/assignPermSetLicenses.apex"
PERM_SET_SCRIPT="scripts/apex/assignPermsets.apex"
SETUP_DATA_SCRIPT="scripts/apex/setupData.apex"
PAUSE_DURATION=60

# --- Script Steps ---
echo ">>> Starting Revenue Cloud scratch org setup for alias: $ORG_ALIAS"

echo "\n>>> 1. Creating the scratch org..."
sfdx force:org:create -f $SCRATCH_DEF_FILE -a $ORG_ALIAS -s --durationdays 30

echo "\n>>> 2. Generating a password for the default user..."
sfdx force:user:password:generate -u $ORG_ALIAS

echo "\n>>> 3. Assigning Permission Set Licenses..."
sfdx force:apex:execute -f $PERM_LICENSE_SCRIPT

echo "\n>>> Pausing for $PAUSE_DURATION seconds (1 minutes) to allow features to provision..."
i=$PAUSE_DURATION
while [ $i -gt 0 ]; do
  printf "\r...Waiting for %d seconds " "$i"
  sleep 1
  i=$((i - 1))
done
echo "\nPause complete."

echo "\n>>> 4. Enabeling Billing"
sfdx project deploy start -d force-app/main/default/settings

echo "\n>>> 5. Assigning Permission Sets..."
sfdx force:apex:execute -f $PERM_SET_SCRIPT

echo "\n>>> 6. Deploying Context Defintions"
sfdx project deploy start -d force-app/main/default/contextDefinitions

echo "\n>>> 7. Deploying Expression Set Definitions"
sfdx project deploy start -d force-app/main/default/expressionSetDefinition

echo "\n>>> 8. Deploying Order To Billing Schedule flow"
sfdx project deploy start -d force-app/main/default/flows

echo "\n>>> 9. Deploying Page Layouts"
sfdx project deploy start -d force-app/main/default/layouts

echo "\n>>> 10. Executing Apex script to create core data..."
sfdx force:apex:execute -f $SETUP_DATA_SCRIPT

echo "\n>>> 11. Opening the new scratch org..."
sfdx force:org:display -u $ORG_ALIAS

echo "\n✅ --- Org setup complete! ---"