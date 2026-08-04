# Spec Review Workflow

Review business flow documents (drawio, markdown, PDF) → identify gaps → cross-reference codebase → compile questions for BA.

## Reading .drawio Files

.drawio = XML mxGraph format. `read_file` works directly — no conversion needed.

**Structure:**
- `<mxfile>` root → multiple `<diagram>` pages (each = 1 flow)
- Each diagram has `<mxCell>` nodes (steps, decisions, swimlanes) and edges (arrows)
- Swimlane headers in cells with `fillColor` + `fontStyle=1`
- Step text in `value` attribute (HTML-encoded)
- Decision nodes: `shape=rhombus`
- Edge labels: `value` attribute on `<mxCell edge="1">`

**Extraction approach:**
1. Read full file (may be 1000+ lines for complex flows)
2. Parse `<diagram name="...">` to identify pages
3. Extract swimlane headers (role lanes)
4. Extract step cells (rounded rectangles with `Bước` in value)
5. Extract decision cells (rhombus shape)
6. Extract edge labels (flow conditions)
7. Reconstruct as human-readable step list

**Tips:**
- File can be 150KB+ — read in chunks if truncated
- Vietnamese text is HTML-encoded in `value` attributes
- Color coding: white = role action, blue = system, green = result, red = warning, purple dashed = exception

## Cross-Referencing with Codebase

After reading the spec, verify against code to answer questions:

1. **Find types/interfaces** matching spec entities (e.g., `DigitalSignatureDossierDto`)
2. **Find schemas** matching spec validation rules (e.g., `digitalSignatureProfileSchema`)
3. **Find constants** matching spec enums (e.g., `KEY_GEN_TYPES`, `SUBJECT_TYPES`)
4. **Check required fields** in Zod schemas vs spec requirements
5. **Check conditional logic** (superRefine, if-statements) for business rules

**Pattern:**
```
Spec says: "CSR required for HSM"
Code says: if (keyGenType === 'HSM' && !csrFile) → addIssue(...)
Answer: CSR required only when keyGenType = HSM ✓
```

## Compiling Questions for BA

After cross-referencing, compile remaining gaps:

**Categories:**
1. **Flow gaps** — Steps not defined, unclear transitions
2. **Role gaps** — Who does what not specified
3. **Data gaps** — Fields/entities not in code
4. **Logic gaps** — Business rules not implemented
5. **Edge cases** — Error handling, exceptions not defined

**Format:**
```
### Câu #N: [Title]
[What the spec says]
[What's unclear]
[Code evidence if available]
```

## Example Output

```markdown
### Câu #2: CSR do ai tạo?
Code tại `digital-signature-profile.schema.ts`:
- csrFile: File upload, optional
- csrSource: 'UPLOAD' | 'HSM_GENERATE'
- Required only when keyGenType = HSM

Kết luận: CSR là file upload, chỉ cần khi HSM.
```
