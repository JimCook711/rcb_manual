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
echo "\n>>> 1. Assigning Permission Set Licenses..."
sf apex run -f $PERM_LICENSE_SCRIPT

echo "\n>>> Pausing for $PAUSE_DURATION seconds (1 minutes) to allow features to provision..."
i=$PAUSE_DURATION
while [ $i -gt 0 ]; do
  printf "\r...Waiting for %d seconds " "$i"
  sleep 1
  i=$((i - 1))
done
echo "\nPause complete."

echo "\n>>> 2. Assigning Permission Sets..."
sf apex run -f $PERM_SET_SCRIPT

echo "\n>>> 3. Deploying Order To Billing Schedule flow"
sf project deploy start -d force-app/main/default/flows

echo "\n>>> 4. Deploying Page Layouts"
sf project deploy start -d force-app/main/default/layouts

echo "\n>>> 5. Executing Apex script to create core data..."
sf apex run -f $SETUP_DATA_SCRIPT

echo "\n>>> 6. Opening the new scratch org..."
sf org open -o $ORG_ALIAS

echo "\n✅ --- Org setup complete! ---"