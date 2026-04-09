export NODE_OPTIONS=--max-old-space-size=8196
#!/bin/bash

install_op() {
    read -p "1Password CLI (op) is not installed but needed for setting the id/secret of the connected app. Do you want to install it via Homebrew? (y/n) " choice
    case "$choice" in
        y|Y )
            echo "Installing 1Password CLI..."
            brew install 1password-cli
            if ! command -v op &> /dev/null; then
                echo "Error: 1Password CLI installation failed."
                exit 1
            fi
            ;;
        n|N )
            echo "1Password CLI is required. Exiting."
            exit 1
            ;;
        * )
            echo "Invalid input. Please enter y or n."
            install_op
            ;;
    esac
}

if [ $# -lt 1 ]
then
    echo Usage: setup_scratch_org.sh alias
    exit
fi

if [ $# -eq 2 ]
then
  DEPLOY_UNPACKAGED=$2
else
  DEPLOY_UNPACKAGED=1
fi

# bring in local config variables
source config/localhost.cfg

if [ -z "$SCRATCH_ORG_DEF" ]; then
    SCRATCH_ORG_DEF="config/project-scratch-def.json"
fi

if [[ "$SCRATCH_ORG_DEF" == *"hc-project-scratch-def.json" && $DEPLOY_UNPACKAGED -eq 1 ]]; then
    DEPLOY_HC=1
else
    DEPLOY_HC=0
fi

SCRATCH_ORG_ALIAS="${1:-dev}"

#install 1p if not available
if ! command -v op &> /dev/null; then
    install_op
fi

# set connected app values
git update-index --skip-worktree ./force-app/main/customMetadata/Setup_Configuration.Default.md-meta.xml
output=$(op item get "CredCheck Connected App Keys" --fields notesPlain --format json | jq -r '.value')
if [[ $? -ne 0 || -z "$output" || "$output" == "null" ]]; then
    echo "Error: Failed to retrieve connected app keys from 1Password."
    echo "Ensure the item exists and you have access to the proper vault."
    exit 1
fi
CLIENT_ID=$(echo "$output" | jq -r '.CREDCHECK_CLIENT_ID')
CLIENT_SECRET=$(echo "$output" | jq -r '.CREDCHECK_CLIENT_SECRET')
FILE_PATH=./force-app/main/customMetadata/Setup_Configuration.Default.md-meta.xml
sed -i '' "s/CREDCHECK_CLIENT_ID/$CLIENT_ID/g" $FILE_PATH
sed -i '' "s/CREDCHECK_CLIENT_SECRET/$CLIENT_SECRET/g" $FILE_PATH
echo "Secrets have been set in metadata file"

# Check if scratch org already exists
if ! sf org list --all --json | jq -e '.result | .scratchOrgs[]?, .nonScratchOrgs[]?, .devHubs[]? | select(.alias == "'"$SCRATCH_ORG_ALIAS"'")' > /dev/null; then
    echo "Creating scratch org '$SCRATCH_ORG_ALIAS'..."
    sf org create scratch --alias "$SCRATCH_ORG_ALIAS" --definition-file "$SCRATCH_ORG_DEF" --duration-days 30 --set-default || {
        echo "Error: Failed to create scratch org."
        exit 1
    }
    sf project deploy start --target-org "$SCRATCH_ORG_ALIAS" || {
        echo "Error: Failed to deploy."
        exit 1
    }
else
    echo "Scratch org '$SCRATCH_ORG_ALIAS' already exists. Skipping creation."
    sf project reset tracking --no-prompt
    sf project deploy start --target-org "$SCRATCH_ORG_ALIAS" --source-dir force-app --ignore-conflicts || {
        echo "Error: Failed to push source."
        exit 1
    }
fi

# assign permission sets
assets/scripts/bash/assign_default_permsets.sh "$SCRATCH_ORG_ALIAS"

# create setup data record
sf data import tree --files assets/importData/Setup_Data__c.json --target-org "$SCRATCH_ORG_ALIAS"

if [[ $DEPLOY_UNPACKAGED == 1 ]];
then
# Swap .forceignore for unpackaged deploy
mv .forceignore .forceignore_original
cp unpackaged/.forceignore .forceignore

# Get instance URL and update remote site setting
REMOTE_SITE_FILE=./unpackaged/remoteSiteSettings/WebhookEndpoint.remoteSite-meta.xml
INSTANCE_URL=$(sf org display --target-org "$SCRATCH_ORG_ALIAS" --json | jq -r '.result.instanceUrl')
if [[ -z "$INSTANCE_URL" || "$INSTANCE_URL" == "null" ]]; then
    echo "Error: Failed to get instance URL."
    exit 1
fi

INSTANCE_URL=$(echo "$INSTANCE_URL" | sed "s/salesforce.com/salesforce-sites.com/g")
sed -i '' "s|<url>.*</url>|<url>$INSTANCE_URL</url>|g" "$REMOTE_SITE_FILE"

echo "Deploying unpackaged directory"
sf project deploy start --source-dir unpackaged --target-org $1 --wait 60

sf project reset tracking --no-prompt

sf org assign permset --name CredCheck_Extension_Dev_User --target-org "$SCRATCH_ORG_ALIAS"

# Restore .forceignore
mv .forceignore_original .forceignore

# Setup guest user, public site, platform events, mapped provider trigger
sf apex run --file assets/scripts/apex/updateGuestUser.apex --target-org "$SCRATCH_ORG_ALIAS" --json
sf apex run --file assets/scripts/apex/updateSetupData.apex --target-org "$SCRATCH_ORG_ALIAS" --json
sf apex run --file assets/scripts/apex/set_Platform_Event_RefreshUI.apex --target-org "$SCRATCH_ORG_ALIAS" --json
sf apex run --file assets/scripts/apex/enable_mapped_provider_trigger.apex --target-org "$SCRATCH_ORG_ALIAS" --json
fi

# Deploy Health Cloud metadata if applicable
if [[ $DEPLOY_HC == 1 ]];
then
    mv .forceignore .forceignore_original
    cp unpackaged-hc/.forceignore .forceignore

    sf project deploy start --source-dir unpackaged-hc --target-org $1 --wait 60
    sf project reset tracking --no-prompt

    sf org assign permset --name CredCheck_HC_Extension_Dev_User --target-org "$SCRATCH_ORG_ALIAS"
    sf org assign permset --name HealthCloudProviderNetworkManagement --target-org "$SCRATCH_ORG_ALIAS"
    sf org assign permset --name HealthCloudPRM --target-org "$SCRATCH_ORG_ALIAS"

    mv .forceignore_original .forceignore
fi

assets/scripts/bash/set_default_scratch_org.sh "$SCRATCH_ORG_ALIAS"

if [[ $ENABLE_ON_ORG_CREATE == "true" ]];
then
  assets/scripts/bash/enable_localhost.sh "$SCRATCH_ORG_ALIAS"
fi

sf org open --target-org $SCRATCH_ORG_ALIAS --path /lightning/n/credcheck__Setup

echo "Scratch org setup completed for: $SCRATCH_ORG_ALIAS"

echo "Login Creds for QA User"
if ! sf org display user -o qa-user --json > /dev/null 2>&1; then
    echo "Creating qa-user..."
    sf org create user --set-alias qa-user --definition-file config/scratch-user.json --target-org "$SCRATCH_ORG_ALIAS"
else
    echo "qa-user already exists."
fi
sf org user display -o qa-user
