# Analyzing Flow Documents Before Interface Design

## .drawio / mxGraph XML Format

.drawio files are XML (mxGraph format). Readable as plain text. Key structure:

```xml
<mxfile host="app.diagrams.net" pages="6">
  <diagram id="..." name="Page Name">
    <mxGraphModel>
      <root>
        <mxCell id="..." value="Label text" style="..." vertex="1">
          <mxGeometry x="..." y="..." width="..." height="..." />
        </mxCell>
        <mxCell id="..." source="..." target="..." edge="1" value="Edge label">
          <mxGeometry ... />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### Extracting Flow Information

1. **Pages**: Each `<diagram>` = one flow page. Check `name` attribute for topic.
2. **Steps/Nodes**: `<mxCell vertex="1">` with `value` containing HTML-encoded labels.
   - Decode HTML entities: `&lt;` = `<`, `&gt;` = `>`, `&amp;` = `&`, `&nbsp;` = space
   - Bold text: `<b>Bước N</b>` = step label
   - Line breaks: `<br/>` or `<br>`
3. **Edges/Flow**: `<mxCell edge="1">` with `source`/`target` IDs and optional `value` for labels.
4. **Decision nodes**: `shape=rhombus` in style → diamond/decision shape.
5. **Swimlanes**: Groups of nodes at same x-position = roles/actors.

### Workflow: Flow → Questions → Code

1. Read .drawio XML, extract steps and edges
2. Identify gaps: undefined roles, missing error paths, vague transitions
3. Create structured question list (numbered, categorized)
4. Cross-reference against codebase: check types, schemas, existing implementations
5. Answer what code can answer, flag the rest for BA

### Common .drawio Entity Patterns

| Pattern in `value` | Meaning |
|---|---|
| `Bước N` | Process step |
| `Quyết định` + rhombus | Decision point |
| `Điểm kiểm soát` | Control/checkpoint |
| `Điểm bàn giao` | Handoff between roles |
| `Lưu ý` | Note/warning |
| `Ngoại lệ` | Exception path (often dashed edges) |
