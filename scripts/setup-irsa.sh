#!/bin/bash
set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Configuration
CLUSTER_NAME="dapr-microservices-cluster"
AWS_REGION="us-east-1"
NAMESPACE="default"
SERVICE_ACCOUNT_NAME="dapr-service-account"
ROLE_NAME="DaprSNSSQSRole"

echo "Setting up IAM roles for service accounts (IRSA)..."

# Use org-demo profile
AWS_PROFILE="org-demo"
echo "Using AWS Profile: $AWS_PROFILE"

# Get account ID from org-demo profile
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text) || {
  echo "Error: Failed to get AWS Account ID from profile $AWS_PROFILE"
  echo "Make sure profile exists: aws configure --profile org-demo"
  exit 1
}
echo "Using AWS Account ID: $AWS_ACCOUNT_ID"

# Check if EKS cluster exists
echo "Checking if EKS cluster exists..."
if ! aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE &>/dev/null; then
    echo "❌ EKS cluster '$CLUSTER_NAME' not found"
    echo "Create cluster first: eksctl create cluster -f infrastructure/eks-cluster.yaml"
    exit 1
fi
echo "✅ EKS cluster found"

# Create IAM policy for SNS/SQS access
echo "Creating IAM policy for SNS/SQS access..."
cat > dapr-sns-sqs-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish",
                "sns:Subscribe",
                "sns:CreateTopic",
                "sns:GetTopicAttributes",
                "sns:SetTopicAttributes",
                "sns:ListTopics"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:CreateQueue",
                "sqs:GetQueueAttributes",
                "sqs:SetQueueAttributes",
                "sqs:ListQueues",
                "sqs:PurgeQueue"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create or update the policy
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/DaprSNSSQSPolicy"
aws iam create-policy \
    --policy-name DaprSNSSQSPolicy \
    --policy-document file://dapr-sns-sqs-policy.json \
    --description "Policy for Dapr SNS/SQS access" \
    --profile $AWS_PROFILE 2>/dev/null || {
    echo "Policy already exists, updating..."
    aws iam create-policy-version \
        --policy-arn $POLICY_ARN \
        --policy-document file://dapr-sns-sqs-policy.json \
        --set-as-default \
        --profile $AWS_PROFILE
}

# Create trust policy for the role
echo "Creating trust policy..."
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||')"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||'):sub": "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}",
                    "$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||'):aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Create IAM role
echo "Creating IAM role..."
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "Role for Dapr SNS/SQS access via IRSA" \
    --profile $AWS_PROFILE 2>/dev/null || {
    echo "Role already exists, updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name $ROLE_NAME \
        --policy-document file://trust-policy.json \
        --profile $AWS_PROFILE
}

# Attach policy to role
echo "Attaching policy to role..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN \
    --profile $AWS_PROFILE

# Update the Dapr pubsub configuration with the correct role ARN
echo "Updating Dapr pubsub configuration..."
sed -i.bak "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" k8s/dapr-pubsub.yaml

# Clean up temporary files
rm -f dapr-sns-sqs-policy.json trust-policy.json

echo "✅ IRSA setup completed successfully!"
echo "Role ARN: $ROLE_ARN"
echo "Service Account: $SERVICE_ACCOUNT_NAME"
echo ""
echo "Next steps:"
echo "1. Deploy the updated Dapr configuration: kubectl apply -f k8s/dapr-pubsub.yaml"
echo "2. Restart your deployments to use the new service account"