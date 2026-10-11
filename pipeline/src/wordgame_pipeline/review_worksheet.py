"""Export editable review drafts without turning proposals into approval."""

import csv
import io


def export_worksheet(report: dict) -> str:
    """Return canonical-column CSV for unique required forms in a valid report."""
    records: dict[str, tuple] = {}
    for level in report["levels"]:
        for annotation in level["required"]:
            word = annotation["word"]
            record = tuple(annotation[key] for key in ("band", "status", "reviewer", "rationale"))
            if word in records and records[word] != record:
                raise ValueError(f"inconsistent repeated review: {word}")
            records[word] = record
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(["word", "band", "status", "reviewer", "rationale"])
    for word, record in sorted(records.items()):
        if record[1] == "missing":
            record = (None, "proposed", "unassigned", "Awaiting curator review")
        writer.writerow((word, *record))
    return output.getvalue()
