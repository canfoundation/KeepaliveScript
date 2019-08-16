#!/bin/bash
# Change these vars based on your node configuration
NODEOS_HTTP=localhost
NODEOS_PORT=8888
SLACK_WEBHOOK=https://hooks.slack.com/services/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
ELASTIC_IP=35.154.77.94
INSTANCE_ID=i-0c1ad322b345f3997
TYPE_NODE=MASTER
BP_NAME=LondonBP

# These are sent via keepalived
TYPE=$1
NAME=$2
STATE=$3

# Echo the result of the pause/resume curl and call slack if relevant
# This could be switched out for any service such as Pager Duty, etc
function notify()
{
    MESSAGE=$1
    echo $MESSAGE
    [[ ! -z $SLACK_WEBHOOK ]] && curl -s -X POST --data-urlencode "payload={\"channel\": \"#can-testnet\", \"username\": \"$BP_NAME\", \"text\": \"$MESSAGE\", \"icon_emoji\": \":ghost:\"}" $SLACK_WEBHOOK > /dev/null
}

function update_elastic_ip()
{
  aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_IP --allow-reassociation > /dev/null
  aws ec2 describe-addresses --output text | grep $INSTANCE_ID | grep $ELASTIC_IP > /dev/null
  if [ $? -eq 0 ]
  then
    notify "$TYPE_NODE assigns $ELASTIC_IP to $INSTANCE_ID"
  else
    notify "$TYPE_NODE could not assign $ELASTIC_IP to $INSTANCE_ID, investigate immediately"
  fi
}

function resume_nodeos()
{
    RESULT=$(curl -s "$NODEOS_HTTP:$NODEOS_PORT/v1/producer/resume")
    if [ "$RESULT" == "{\"result\":\"ok\"}" ]
    then
        notify "$TYPE_NODE successfully promoted to the primary producer"
    else
        notify "$TYPE_NODE failed to resume, investigate immediately"
    fi
}

function pause_nodeos()
{
    RESULT=$(curl -s "$NODEOS_HTTP:$NODEOS_PORT/v1/producer/pause")
    if [ "$RESULT" == "{\"result\":\"ok\"}" ]
    then
        notify "$TYPE_NODE successfully relegated to secondary producer"
    else
        notify "$TYPE_NODE failed to pause, investigate immediately"
    fi
}

# Based on the state, perform the relevant action
case $STATE in
    "MASTER") update_elastic_ip
              resume_nodeos
              exit 0
              ;;
    "BACKUP") pause_nodeos
              exit 0
              ;;
    "FAULT")  notify "$TYPE_NODE changes FAULT state"
              exit 0
              ;;
esac