"""Read published Soviet/German model folders; snapshot reviewed static GLBs for research UI.
This does not create combat definitions or accept a WIP folder as a delivery.
"""
import json, hashlib
from pathlib import Path
from research_combat_bindings import apply_bindings
from build_research_runtime_profiles import build as build_runtime_profiles
ROOT = Path(__file__).resolve().parents[2]
EXTERNAL = Path("E:/AIprogram/aimodel")
def digest(data): return hashlib.sha256(data).hexdigest()
def sync():
    target = ROOT / "assets/research/soviet_german_tree.json"
    catalog = json.loads(target.read_text(encoding="utf-8-sig"))
    entries = {row["id"]: row for row in catalog["vehicles"]}
    found = {}; issues = []
    for nation in ["苏联", "德国"]:
        for report in sorted((EXTERNAL/nation).rglob("build_report.json")):
            if any(part in report.parts for part in ["制作中", "历史版本"]): continue
            paths = [report, report.parent/"verification.json", report.parent/"visual_review.json", report.parent/"vehicle.glb"]
            if not all(p.exists() for p in paths): continue
            rb, vb, ib, data = [p.read_bytes() for p in paths]
            r, v, review = [json.loads(b) for b in [rb, vb, ib]]
            identity = r.get("id")
            if identity not in entries:
                issues.append(dict(path=str(report), reason="no exact cache identity")); continue
            if not (v.get("status")=="PASS" or v.get("passed") is True) or review.get("status")!="PASS": continue
            sha = digest(data)
            expected = review.get("sha256",{}).get("vehicle.glb") or v.get("glb_sha256") or v.get("sha256",{}).get("vehicle.glb")
            if expected and expected != sha:
                issues.append(dict(id=identity,reason="model hash conflicts with review")); continue
            # A moving external producer cannot change the selected bytes mid-copy.
            if any(p.read_bytes()!=b for p,b in zip(paths,[rb,vb,ib,data])):
                issues.append(dict(id=identity,reason="source changed during snapshot")); continue
            if identity in found and found[identity]["sha256"]!=sha:
                raise ValueError("conflicting root deliveries for "+identity)
            artifact = ROOT / "assets/research/models" / (identity+".glb")
            artifact.parent.mkdir(parents=True,exist_ok=True)
            artifact.write_bytes(data)
            found[identity]=dict(path="res://"+artifact.relative_to(ROOT).as_posix(),sha256=sha,source_path=paths[-1].as_posix(),report_sha256=digest(rb),verification_sha256=digest(vb),visual_review_sha256=digest(ib),geometry_status="PASS",visual_status="PASS",status="reviewed_static_model",human_accepted=False,combat_admitted=False,triangles=r.get("triangles"),hash_bound_to_review=bool(expected))
    for row in entries.values():
        row["model"]=found.get(row["id"])
        row["admission_status"]="static_preview_only" if row["model"] else "awaiting_model"
    catalog["issues"]=issues
    catalog=apply_bindings(catalog)
    catalog["models"]={nation:sum(row["nation"]==nation and row["model"] is not None for row in entries.values()) for nation in ["ussr","germany"]}
    target.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    build_runtime_profiles()
    print(catalog["counts"],catalog["models"],issues)
if __name__=="__main__": sync()
