#!/bin/bash

# Variables
AWS_REGION="us-west-2"
INSTANCE_TYPE="t2.micro"
INSTANCE_NAME="Rebuild-Jenkins-Instance"
S3_BUCKET_NAME="njd-vpro-ci-cd-stack-backup"
BACKUP_FILE_NAME="jenkins_cicdjobs.tar.gz"

# Launch EC2 instance
instance_id=$(
  aws ec2 run-instances \
    --region $AWS_REGION \
    --image-id ami-03f65b8614a860c29 \
    --instance-type $INSTANCE_TYPE \
    --key-name ci-njd-training-oregon-us-west-2 \
    --subnet-id subnet-014413530d20cac25 \
    --security-group-ids sg-07f7659b0e69036dd \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' \
    --output text
)

echo "Launched EC2 instance with ID: $instance_id"

# Wait for the instance to be running
aws ec2 wait instance-running --instance-ids $instance_id --region $AWS_REGION

# Get the public IP address of the instance
public_ip=$(
  aws ec2 describe-instances \
    --region $AWS_REGION \
    --instance-ids $instance_id \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
)

echo "Public IP address: $public_ip"

# Wait for SSH connectivity
echo "Waiting for SSH connectivity..."
sleep 30

# SSH into the instance and execute commands
ssh -i /home/mr.wolf/keys/ci-njd-training-oregon-us-west-2.pem ubuntu@$public_ip <<EOF
  # Update the package manager
  sudo apt update
  
  # Install Java, Wget, and other dependencies
  sudo apt install -y default-jdk wget
  
  # Install Jenkins
  wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
  sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
  sudo apt update
  sudo apt install -y jenkins
  
  # Start Jenkins service
  sudo systemctl start jenkins
  
  # Upload Jenkins backup file from S3
  aws s3 cp s3://$S3_BUCKET_NAME/$BACKUP_FILE_NAME ~/
  
  # Restore Jenkins backup
  sudo tar -xzf $BACKUP_FILE_NAME -C /var/lib/jenkins
  
  # Set correct ownership and permissions
  sudo chown -R jenkins:jenkins /var/lib/jenkins
  sudo chmod -R 755 /var/lib/jenkins
EOF

echo "Setup completed successfully."
