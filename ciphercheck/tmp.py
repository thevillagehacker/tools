import boto3

# Replace with your actual AWS Access Key ID and Secret Access Key
AWS_ACCESS_KEY_ID = 'AKIAIOSFODNN7EXAMPLE'
AWS_SECRET_ACCESS_KEY = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
AWS_REGION = 'your-aws-region' # e.g., 'us-east-1'

try:
    # Create a Boto3 session with hardcoded credentials
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION
    )

    # Example: Create an S3 client using the session
    s3_client = session.client('s3')

    # Example: List S3 buckets
    response = s3_client.list_buckets()
    print("S3 Buckets:")
    for bucket in response['Buckets']:
        print(f"  {bucket['Name']}")

except Exception as e:
    print(f"An error occurred: {e}")