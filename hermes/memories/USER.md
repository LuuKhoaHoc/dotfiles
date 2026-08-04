Hilo ERP (công ty) = ERP Admin gitlab.vppos.vn. MFE: sale/finance/product/employee/hr/apps-dashboard/shell.
§
User preference: friendly but concise. Vietnamese for conversation, English for code. Update issue descriptions directly (not notes) when adding tasks. Research web for latest tech stack.
§
§ User prefers normal/verbose communication — explicitly requested removal of Ponytail (caveman) plugin. Do not use terse/caveman style.
§
User prefers clean architecture over fear of breaking changes — 'không sợ breaking changes', 'ưu tiên pattern và chuẩn best practice của react lên hàng đầu'. Explicitly wants React 19 best practices (SRP, composition) prioritized, even if it means significant refactoring.
§
Preferred issue format: ## What to build (user perspective, end-to-end), ## Acceptance criteria (checklist), ## Blocked by (issue refs or 'None'), ## References (uploaded doc links). Follow to-tickets skill style.
§
Khi tạo issue GitLab: upload file API docs qua upload_markdown trước, link trong ## References. Tạo blocker issues trước, rồi dependent issues. Assign milestone qua milestone_id. Batch concurrent updates cho issue không phụ thuộc.