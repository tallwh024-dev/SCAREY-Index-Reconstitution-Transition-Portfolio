# Project Summary

This project constructs an optimized transition plan for a portfolio benchmarked to the SCAREY Index during a REIT index reconstitution event.

## Objective

The portfolio starts aligned with the current benchmark, which includes REITs beginning with M, N, O, and P. It transitions toward the future benchmark, which includes REITs beginning with P, R, and S.

The goal is to control active risk while meeting a minimum expected excess return requirement of 2 basis points per week.

## Benchmark transition

| Decision Point | Current Benchmark | Future Benchmark |
|---|---:|---:|
| b_4 | 100% | 0% |
| b_3 | 80% | 20% |
| b_2 | 60% | 40% |
| b_1 | 30% | 70% |
| b_0 | 0% | 100% |

## Expected transition results

| Decision Point | Current Tracking Error | Future Tracking Error | Blended Expected Excess Return |
|---|---:|---:|---:|
| b_4 | 0.000082 | 0.005974 | 0.000200 |
| b_3 | 0.001197 | 0.004788 | 0.000202 |
| b_2 | 0.002394 | 0.003591 | 0.000201 |
| b_1 | 0.004190 | 0.001796 | 0.000237 |
| b_0 | 0.005985 | 0.000000 | 0.000200 |

## Conclusion

The optimized strategy provides a smooth transition from the current benchmark to the future benchmark. It keeps expected excess return near the required 2 basis points per week while gradually reducing tracking error relative to the future index composition.
