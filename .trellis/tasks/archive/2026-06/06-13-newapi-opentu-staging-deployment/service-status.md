# Staging service status
timestamp_utc=2026-06-13T15:26:11+00:00

## docker compose ps
NAME                            IMAGE                                    COMMAND                  SERVICE   CREATED         STATUS                   PORTS
newapi-opentu-staging-new-api   new-api-creative-embed:staging-current   "/new-api --log-dir …"   new-api   8 minutes ago   Up 8 minutes (healthy)   127.0.0.1:39084->3000/tcp

## readiness
status=200
content-type=application/json; charset=utf-8

## ignored env file
ops/newapi-opentu-staging/.gitignore:1:.env.staging.local	ops/newapi-opentu-staging/.env.staging.local
