# Optimization

## Findings

### Default offline generation protects perceived speed

- Evidence: `TuneProviderMode.offlineFormula` is the default and `LocalSampleTuneProvider` returns after short simulated delay.
- Expected user-visible benefit: fast first tune without network or account setup.
- Verification method: UI smoke and provider tests.
- Remaining risk: artificial sleeps add perceived delay; consider shortening/removing only if loading state no longer needs demonstration time.

### Thumbnail storage already downsizes screenshots

- Evidence: `NewTuneStartView.thumbnailData(from:)` caps largest side at 480 and JPEG quality at 0.68.
- Expected user-visible benefit: lower SwiftData storage and faster garage row display.
- Verification method: inspect saved thumbnails and garage performance with many saved tunes.
- Remaining risk: no bulk garage performance test.

### No optimization implemented beyond copy/test slice

- This loop prioritizes reliability and first-run clarity over runtime optimization.
