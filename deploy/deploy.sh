#!/bin/bash


ACTION=$1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MYIP=`dig +short myip.opendns.com @resolver1.opendns.com`

# Required if not using an AWS Instance Profile on httpd server
AWS_ACCESS_KEY="$( cat ~/.aws/credentials | grep aws_access_key | awk '{print $3}' )"
AWS_SECRET_ACCESS_KEY="$( cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print $3}' )"

function wait_completed {
    STATUS="$( aws cloudformation describe-stacks --stack-name sqs | grep StackStatus )"

    while [[ ${STATUS} != *"CREATE_COMPLETE"* ]]; do
        echo "waiting for stack ${1} to complete..."
        sleep 5
    done
}

function create {
    echo ">>> Deploying stacks..."

    aws cloudformation create-stack --stack-name httpd --template-body file://deploy/cf-apache-httpd.yml \
        --parameters ParameterKey=KeyName,ParameterValue=gen_key_pair ParameterKey=DBRootPassword,ParameterValue=MyPassword123 \
        ParameterKey=DBPassword,ParameterValue=MyPassword123 ParameterKey=SSHLocation,ParameterValue=${MYIP}/32 \
        --capabilities CAPABILITY_IAM

    wait_completed httpd

    aws cloudformation create-stack --stack-name nifi --template-body file://deploy/cf-nifi.yml \
        --parameters ParameterKey=KeyName,ParameterValue=gen_key_pair ParameterKey=RemoteLocation,ParameterValue=${MYIP}/32 \
        --capabilities CAPABILITY_IAM

    wait_completed nifi

    aws cloudformation create-stack --stack-name sqs --template-body file://deploy/cf-sqs.yml \
        --parameters ParameterKey=BucketName,ParameterValue=httpd-logs

    wait_completed sqs

    # get sqs queue arn
    SQSQueueArn="$( aws sqs list-queues --queue-name-prefix SQSQueue | \
        grep https://queue.amazonaws.com | \
        awk '{$1=$1};1' | \
        xargs aws sqs get-queue-attributes --attribute-names All --queue-url | \
        grep QueueArn | \
        awk '{print $2}' | \
        sed 's/\"//g' )"

    # get logs bucket name
    LogsBucket="$( aws s3api list-buckets | grep httpd-logs | awk '{print $2}' | sed 's/\"//g' )"

    # update notification config with sqs arn
    sed -i "s;\"QueueArn\":.*;\"QueueArn\": \"${SQSQueueArn}\",;" deploy/config/log-bucket-notification-config.json

    # create sqs queue notification
    aws s3api put-bucket-notification-configuration --bucket ${LogsBucket}  \
        --notification-configuration file://./deploy/config/log-bucket-notification-config.json

}

function delete {
    echo ">>> Deleting stacks..."
    aws cloudformation delete-stack --stack-name httpd
    aws cloudformation delete-stack --stack-name nifi
    aws cloudformation delete-stack --stack-name sqs

}

if [[ ${ACTION} == "create" ]]; then
    create

elif [[ ${ACTION} == "delete" ]]; then
    delete
else
    echo "argument error; please supply one of the following arguments: ['create', 'delete']"
fi
