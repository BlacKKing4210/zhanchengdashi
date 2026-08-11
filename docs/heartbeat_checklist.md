# Current-Batch Heartbeat Checklist

1. Verify the RAG gate and create a heartbeat-specific context receipt.
2. Read the cited sections of `docs/active_scope.yaml`.
3. Inspect only active batch tasks and required dependencies.
4. Verify latest receipt, owner authorization, Skills, write scope, baselines, shared locks, recent progress, and process state.
5. Check candidate/not-runtime leakage and temporary output boundaries.
6. Detect stalls from output, tool, process, and receipt evidence.
7. Report exceptions immediately; keep healthy checks quiet.
8. Refresh `PM/feature_progress.xlsx` when due or explicitly requested.
9. Refresh RAG if the workbook or another active source changed.
10. Preserve Nine Dimensions as the first sheet, `Not needed` labels, formulas, priority/feature-ID order, and completed rows last.
