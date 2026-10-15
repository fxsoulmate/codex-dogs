# codex-dogs

Codex-maintained slice of [DOGs](https://github.com/helightdev/dogs): `dogs_core` and `dogs_generator`, including `DogModelCodec` and map-aware `@JsonKey` (`convert` / `each` / `onNullValue` / `forceValue` / aliases).

## Packages

| Package | Path |
| --- | --- |
| `dogs_core` | `packages/dogs_core` |
| `dogs_generator` | `packages/dogs_generator` |

## Use in an app

```yaml
dependency_overrides:
  dogs_core:
    git:
      url: https://github.com/fxsoulmate/codex-dogs.git
      ref: <commit>
      path: packages/dogs_core

dev_dependencies:
  dogs_generator:
    git:
      url: https://github.com/fxsoulmate/codex-dogs.git
      ref: <commit>
      path: packages/dogs_generator
```

Upstream project: [helightdev/dogs](https://github.com/helightdev/dogs).
