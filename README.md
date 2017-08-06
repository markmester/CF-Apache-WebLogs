# Apache Log Pipeline
#### AWS pipeline for for processing Apache httpd logs. Basic flow is as follows:
Apache https logs -> S3 Bucket -> SQS trigger -> NiFi for parsing -> Kinesis/Kafka -> EMR/Redshift

## Quick Deploy:
1. Ensure AWS credentials can be found in: ~/.aws/credentials
2. Deploy using the deploy.sh script: ```./deploy.sh create```


## Notes:
-   This pipeline completed up to the NiFi input stage. Still need to parse logs and send to EMR/Redshift.
