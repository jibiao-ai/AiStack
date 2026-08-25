# Troubleshooting

## View AiStack Logs

You can view AiStack logs with the following commands for the default setup:

```bash
docker logs -f aistack
```

## Enable Debug Mode

You can enable the `DEBUG` mode by setting the `--debug` flag when running AiStack:

```diff
sudo docker run -d --name aistack \
    ...
    aistack/aistack \
+    --debug
    ...
```

You can also enable AiStack's debug mode at runtime by running the following command inside the **server container**:

```bash
aistack reload-config --set debug=true
```

## Configure Log Level

The log level endpoints require authentication.

You can configure log level of the AiStack server at runtime by running the following command inside the **server container**. Authenticate with an admin API key:

```bash
curl -X PUT http://localhost/debug/log_level \
    -H "Authorization: Bearer <YOUR_API_KEY>" \
    -d "debug"
```

The same applies to AiStack workers. Authenticate with the local worker token (defaults to `/var/lib/aistack/worker_token`):

```bash
curl -X PUT http://localhost:10150/debug/log_level \
    -H "Authorization: Bearer $(cat /var/lib/aistack/worker_token)" \
    -d "debug"
```

The available log levels are: `trace`, `debug`, `info`, `warning`, `error`, `critical`.

## Reset Admin Password

In case you forgot the admin password, you can reset it by running the following command inside the **server container**:

```bash
aistack reset-admin-password
```

If you changed the default port using `--port` when starting AiStack, specify the AiStack URL using the `--server-url` parameter. It must be run locally on the server and accessed via `localhost`:

```bash
aistack reset-admin-password --server-url http://localhost:9090
```

## Assist in Accelerators Detection Diagnosis

After successfully deploying the AiStack Worker as described in the [installation guide](./installation/requirements.md),  
if the Worker fails to detect any devices,  
please enter the corresponding Worker container, run the following command, and report the results to [AiStack](https://github.com/aistack/aistack/issues).

```bash
time AISTACK_RUNTIME_LOG_LEVEL=debug AISTACK_RUNTIME_LOG_EXCEPTION=1 aistack-runtime detect --format json
```

## Assist in Model Deployment Diagnosis

If you experience issues after deploying a model, 
please enter the corresponding Worker container, run the following command, and report the results to [AiStack](https://github.com/aistack/aistack/issues).

```bash
aistack-runtime inspect <model instance name>
```
