# Model Naming Convention

## Overview

Model identifiers are prefixed by their **creator/provider** to allow multiple versions of the same model to coexist without overwriting each other. This enables testing and comparison of different quantizations from different providers.

## Creator Prefixes

### bartowski
- **Description**: Standard llama.cpp quantizations with imatrix support
- **Characteristics**: Reliable, predictable, widely compatible with LM Studio
- **Best for**: Production use, stability, broad compatibility
- **Example**: `bartowski/deepseek-r1-distill-llama-70b`

### unsloth
- **Description**: Includes dynamic quantizations (1.58-bit, 2-bit) plus standard quants
- **Characteristics**: Smaller file sizes, better accuracy at low bitrates, newer technology
- **Best for**: Limited VRAM/RAM, experimentation, latest features
- **Example**: `unsloth/deepseek-r1-distill-llama-70b`

## Naming Pattern

```
<creator>/<model-name>
```

Examples:
- `bartowski/deepseek-r1-distill-llama-70b`
- `unsloth/deepseek-r1-distill-llama-70b`
- `bartowski/qwen3.5-35b-a3b`
- `unsloth/qwen3.5-35b-a3b`

## Configuration Files

### prometheus-model-catalog.json
This file lists all available models and their metadata:
- `id`: The full model identifier including creator prefix
- `descriptor`: Human-readable description
- `alias`: Service alias (prefixed with `prometheus/`)
- `contextWindow`, `maxTokens`, `reasoning`: Model properties

### prometheus-model-lock.json
This file contains the actual model sources with hashes:
- Each model has a `source` block with `kind`, `url`, and `sha256`
- Multi-shard models use `multi-shard` kind with `shards` array
- Each shard has its own URL and hash

## Adding New Models

1. Add entry to `prometheus-model-lock.json` with correct hashes
2. Add entry to `prometheus-model-catalog.json` with metadata
3. Update `defaultModel` in catalog if this should be the default

## Ports

Each model gets a unique port:
- Port 11436: First model (llama-3.2-1b-instruct)
- Port 11437: Second model (qwen3.5-35b-a3b)
- Port 11438: Third model (bartowski/deepseek...)
- Port 11439: Fourth model (unsloth/deepseek...)

## Service Names

Generated systemd services follow the pattern:
- `prometheus-llama-<serviceSuffix>`
- Example: `prometheus-llama-bartowski-deepseek-r1-distill-llama-70b`

## Default Model

The `defaultModel` field in `prometheus-model-catalog.json` specifies which model to use when no specific model is requested. Currently set to `bartowski/deepseek-r1-distill-llama-70b` as it provides the most reliable behavior.
