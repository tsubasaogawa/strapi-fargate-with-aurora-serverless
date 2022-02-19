# strapi-fargate-with-aurora-serverless

This repository was rejected.

Run strapi container in a low cost. This repository uses Fargate Spot and Aurora Serverless.

## Usage

### Building infrastructure

```bash
cd terraform
terraform apply -var 'master_password=XXX'
```

### Creating strapi image

```bash
cd ..
docker compose up -d
# after running strapi completed

make commit
# -> PROBLEM: image cannot contain /svr/app directory so that Dockerfile defines `volumes`

make login
make push
```

### Running Fargate

```bash
cd ..
make run_task
# -> PROBLEM: Fargate will fail by `KnexTimeoutError` because of Aurora Serverless?
```

### Access

Browse `http://<Fargate IP>:1337/`
