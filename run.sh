#! ./bin/bash
set -e


echo "===> Applying Infrastructure......"
terraform apply -var-file="terraform.tfvars" --auto-approve \
  -target=module.s3 \
  -target=module.sqs \
  -target=module.iam

echo "===> Uploading lambda zi......"
aws s3 cp modules/lambda/lambda.zip s3://$(terraform output -raw raw_bucket_name)/lambda/lambda.zip

echo "===> redeploying lambda......"
terraform apply -var-file="terraform.tfvars" --auto-approve

echo "==> Done. Run the producer next:"
echo "    cd producer && source .venv312/bin/activate"
echo "    python producer.py --year 2024 --gp Bahrain"