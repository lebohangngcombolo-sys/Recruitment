# OpenRouter Integration Setup

OpenRouter has been integrated as an additional AI option for the recruitment system, providing access to multiple AI models through a unified API.

## Current AI Fallback Chain

1. **Backend API** (first priority)
2. **OpenRouter** (second priority) ⬅️ **NEW**
3. **Firebase Gemini** (third priority)
4. **Default fallback** (final option)

## Setup Instructions

### 1. Get OpenRouter API Key

1. Sign up at [OpenRouter.ai](https://openrouter.ai)
2. Navigate to your API keys section
3. Generate a new API key
4. Copy the key for configuration

### 2. Configure API Key

#### Option A: Environment Variable (Recommended)
```bash
# For development
export OPENROUTER_API_KEY=your_api_key_here

# For production deployment
# Add to your environment variables or deployment platform
```

#### Option B: Build Configuration
```bash
# When building the app
flutter build web --dart-define=OPENROUTER_API_KEY=your_api_key_here
```

### 3. Available Models

The system currently uses:
- **Primary**: `anthropic/claude-3-haiku` (fast, cost-effective)
- **Alternative models** that can be configured:
  - `openai/gpt-4o-mini`
  - `anthropic/claude-3-sonnet`
  - `google/gemini-flash-1.5`

### 4. Usage

Once configured, OpenRouter will automatically be used when:
- Backend API is unavailable
- Backend API returns errors
- Network connectivity issues

The system will seamlessly fall back to Gemini or default responses if OpenRouter fails.

## Benefits

- **Multiple AI Models**: Access to state-of-the-art models from various providers
- **Cost Control**: Choose from models based on cost/performance needs
- **Reliability**: Additional fallback option improves system resilience
- **Flexibility**: Easy to switch between models without code changes

## Model Selection

To change the default OpenRouter model, modify the AIService:

```dart
// In ai_service.dart, change:
return await _tryOpenRouter(jobTitle, 'anthropic/claude-3-haiku');

// To another model:
return await _tryOpenRouter(jobTitle, 'openai/gpt-4o-mini');
```

## Monitoring

Check the console logs for AI service status:
- `"Backend generateJobDetails failed"` - Backend unavailable
- `"OpenRouter failed"` - OpenRouter unavailable  
- `"Gemini failed"` - Gemini unavailable
- `"Using default fallback"` - All AI options failed

## Troubleshooting

1. **API Key Issues**: Ensure the OpenRouter API key is correctly set
2. **Rate Limits**: OpenRouter has rate limits - consider upgrading your plan
3. **Model Availability**: Some models may be temporarily unavailable
4. **Network Issues**: Check internet connectivity for external API calls

## Cost Considerations

- Claude 3 Haiku: ~$0.25/1M tokens (most economical)
- GPT-4o Mini: ~$0.15/1M tokens 
- Claude 3 Sonnet: ~$3/1M tokens (higher quality)

Monitor your OpenRouter dashboard for usage and costs.
