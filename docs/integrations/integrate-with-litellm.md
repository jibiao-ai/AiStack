# Integrate with LiteLLM

LiteLLM can integrate with AiStack to aggregate locally deployed LLMs, embeddings, reranking, Speech-to-Text, and Text-to-Speech capabilities into a unified OpenAI-compatible/Anthropic API gateway for enterprise employees.

## Deploying Models in AiStack

1. In AiStack UI, navigate to the `Deployments` page and click on `Deploy Model` to deploy the models you need. Here are some example models:

- qwen3-8b
- qwen2.5-vl-3b-instruct
- bge-m3
- bge-reranker-v2-m3

![aistack-models](../assets/integrations/integration-aistack-models.png)

2. In the model’s Operations, open `API Access Info` to see how to integrate with this model.

![aistack-api-access-info](../assets/integrations/integration-aistack-api-access-info.png)

## Create an API Key in AiStack

1. Navigate to the `Access Control` > `API Keys` page in AiStack, then click on `New API Key`.

2. Fill in the name, then click `Save`.

3. Copy the API key and save it for later use.

## Integrating AiStack into LiteLLM 

1. Open LiteLLM manage ui

```
http://your-litellm-url:4000/ui
```

![litellm-dashboard](../assets/integrations/litellm-1.png)

2. open models+endpoints menu -> add model

![litellm-add-model1](../assets/integrations/litellm-2.png)
![litellm-add-model2](../assets/integrations/litellm-3.png)

3. test in litellm  ->playgroud

![litellm-chat1](../assets/integrations/litellm-4.png)
