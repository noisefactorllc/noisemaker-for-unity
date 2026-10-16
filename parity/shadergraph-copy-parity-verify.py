#!/usr/bin/env python3
"""Render Shader Graph copies against their pipeline shaders in Unity."""

import copy
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("nm_graph_probe", Path(__file__).with_name("shadergraph-compile-verify.py"))
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)
SIZE = 256
CASES = {
    "Snow": {"Alpha": 0.5, "Pause": 0.0, "Density": 75.0, "Time": 0.25},
    "Polar": {"Time": 0.25, "PolarMode": 0, "Scale": 0, "Rotation": 0,
              "Speed": 0, "AspectLens": 1, "Antialias": 1},
    "Tunnel": {"Time": 0.25, "Shape": 0, "Scale": 0, "Speed": 1,
               "Rotation": 0, "Center": 100, "AspectLens": 1, "Antialias": 1},
    "Spiral": {"NMTime": 0.25, "Strength": -100, "Speed": 0,
               "Rotation": 0, "Wrap": 0, "AspectLens": 1, "Antialias": 1},
    "Refract": {"Mode": 0, "Amount": 50, "Direction": 0, "BlendMode": 10,
                "MixAmt": 50, "Wrap": 0},
    "CellRefract": {"Resolution": SIZE, "Time": 0.25, "RefractAmt": 23,
                    "Direction": 0, "Wrap": 0, "Speed": 1, "Shape": 1,
                    "Scale": 50, "CellScale": 75, "CellSmooth": 0,
                    "Variation": 0, "Seed": 1, "Kernel": 0, "EffectWidth": 0},
    "Kaleido": {"Resolution": SIZE, "Time": 0.25, "Sides": 8,
                "Metric": 0, "LoopOffset": 10, "LoopScale": 1, "Speed": 5,
                "Seed": 1, "Wrap": 1, "Direction": 2, "Kernel": 0,
                "EffectWidth": 0},
    "Glitch": {"Resolution": SIZE, "Time": 0.25, "AspectRatio": 1,
               "FullResolution": SIZE, "TileOffset": 0,
               "Glitchiness": 0, "Aberration": 0, "XChonk": 1, "YChonk": 1,
               "Seed": 1, "ScanlinesAmt": 0, "SnowAmt": 0, "VignetteAmt": 0,
               "Distortion": 0, "AspectLens": 0},
    "GlyphMap": {"CellSize": 16, "Seed": 1, "ColorMode": 1},
    "Crt": {"Resolution": SIZE, "FullResolution": SIZE, "TileOffset": 0,
            "RenderScale": 1, "Time": 0.25, "Alpha": 0.5, "Speed": 1, "Seed": 1},
    "Effects": {"Resolution": SIZE, "Effect": 0, "Flip": 0,
                "FullResolution": SIZE, "TileOffset": 0, "RenderScale": 1,
                "EffectAmt": 1, "ScaleAmt": 100, "Rotation": 0,
                "OffsetX": 0, "OffsetY": 0, "Intensity": 0, "Saturation": 0},
}
CASES["KaleidoShadow"] = dict(CASES["Kaleido"], Kernel=6)
CASES["GlitchActive"] = dict(CASES["Glitch"], Glitchiness=50, Aberration=25,
                             ScanlinesAmt=20, SnowAmt=20, VignetteAmt=-50,
                             Distortion=30)
CASES["EffectsCga"] = dict(CASES["Effects"], Effect=200, EffectAmt=5)
CASES["EffectsSubpixel"] = dict(CASES["Effects"], Effect=210, EffectAmt=5)
CASES["EffectsScaleMid"] = dict(CASES["Effects"], ScaleAmt=212.5)
CASES["GlitchTiled"] = dict(CASES["GlitchActive"], FullResolution=512, TileOffset=128)
CASES["GlitchTiledWide"] = dict(CASES["GlitchActive"], FullResolution=(512, 256),
                                TileOffset=(128, 0), AspectRatio=2)
CASES["GlitchLegacy"] = dict(CASES["GlitchActive"], FullResolution=0.5, TileOffset=0.5)
CASES["GlitchSaved"] = {key: value for key, value in CASES["GlitchActive"].items()
                         if key not in ("FullResolution", "TileOffset")}
CASES["EffectsTiled"] = dict(CASES["EffectsSubpixel"], FullResolution=512, TileOffset=128)
CASES["EffectsBlurTiled"] = dict(CASES["Effects"], Effect=1, FullResolution=512, TileOffset=128)
CASES["EffectsCgaTiled"] = dict(CASES["EffectsCga"], FullResolution=512, TileOffset=128)
CASES["EffectsCgaTiledWide"] = dict(CASES["EffectsCga"], FullResolution=(512, 256),
                                    TileOffset=(128, 0))
CASES["EffectsSubpixelLowTiled"] = dict(CASES["EffectsTiled"], EffectAmt=2)
CASES["EffectsSubpixelLegacy"] = dict(CASES["EffectsSubpixel"], FullResolution=0.5,
                                      TileOffset=0.5, RenderScale=0.5)
CASES["EffectsCgaScaled"] = dict(CASES["EffectsCga"], RenderScale=2)
CASES["EffectsSubpixelScaled"] = dict(CASES["EffectsSubpixel"], RenderScale=2)
CASES["EffectsSubpixelSaved"] = {key: value for key, value in CASES["EffectsSubpixel"].items()
                                if key not in ("FullResolution", "TileOffset", "RenderScale")}
CASES["GlyphMapSmall"] = dict(CASES["GlyphMap"], CellSize=4)
CASES["GlyphMapLarge"] = dict(CASES["GlyphMap"], CellSize=32)
CASES["CrtTiled"] = dict(CASES["Crt"], FullResolution=512, TileOffset=128)
CASES["CrtScaled"] = dict(CASES["Crt"], RenderScale=2)
QUANTIZE_GUID = "e25ed175a52b4600bffb0b0607a2a91e"


def parity_graph(wrapper: Path, template, uv_node, uv_slot, sampler_node, sampler_slot,
                 property_node, property_slot, scalar_property, defaults, saved_schema=False):
    source = PROBE.generate_graph(wrapper, template)
    decoder = json.JSONDecoder()
    objects = []
    while source.strip():
        item, length = decoder.raw_decode(source.lstrip())
        objects.append(item)
        source = source.lstrip()[length:]
    graph = objects[0]
    function = next(item for item in objects if item.get("m_Type") == "UnityEditor.ShaderGraph.CustomFunctionNode")
    function_slots = {item["m_ObjectId"]: item for item in objects if item.get("m_ObjectId")}
    if saved_schema:
        added = {"FullResolution", "TileOffset", "RenderScale"}
        kept = [reference for reference in function["m_Slots"]
                if function_slots[reference["m_Id"]]["m_DisplayName"] not in added]
        old_to_new = {}
        for index, reference in enumerate(kept):
            slot = function_slots[reference["m_Id"]]
            old_to_new[slot["m_Id"]] = index
            slot["m_Id"] = index
        removed_ids = {reference["m_Id"] for reference in function["m_Slots"]} - {
            reference["m_Id"] for reference in kept}
        objects = [item for item in objects if item.get("m_ObjectId") not in removed_ids]
        function["m_Slots"] = kept
        for edge in graph["m_Edges"]:
            for side in ("m_OutputSlot", "m_InputSlot"):
                if edge[side]["m_Node"]["m_Id"] == function["m_ObjectId"]:
                    edge[side]["m_SlotId"] = old_to_new[edge[side]["m_SlotId"]]
    available = {function_slots[reference["m_Id"]]["m_DisplayName"] for reference in function["m_Slots"]}
    missing = set(defaults) - available
    if missing:
        raise ValueError(f"{wrapper.name} missing parity inputs: {sorted(missing)}")
    for reference in function["m_Slots"]:
        slot = function_slots[reference["m_Id"]]
        name = slot["m_DisplayName"]
        if name in defaults:
            value = defaults[name]
            if isinstance(slot.get("m_Value"), dict):
                components = tuple(slot["m_Value"])
                if isinstance(value, tuple):
                    if len(value) != len(components):
                        raise ValueError(f"{wrapper.name} invalid {name} dimensions")
                    value = dict(zip(components, value))
                else:
                    value = {component: value for component in components}
            slot["m_Value"] = value
            slot["m_DefaultValue"] = value
    parameters = []
    if wrapper.stem == "Crt":
        parameters = ["Alpha", "Speed", "Seed", "Time", "RenderScale"]
    elif (wrapper.stem == "Effects" and (defaults["Effect"] == 210 or defaults["ScaleAmt"] != 100)) or wrapper.stem == "Spiral":
        parameters = ["Strength" if wrapper.stem == "Spiral" else (
            "ScaleAmt" if defaults["ScaleAmt"] != 100 else "EffectAmt")]
    for parameter in parameters:
        ids = lambda suffix: hashlib.md5((wrapper.stem + ":parity:" + parameter + ":" + suffix).encode()).hexdigest()
        node = copy.deepcopy(property_node)
        slot = copy.deepcopy(property_slot)
        prop = copy.deepcopy(scalar_property)
        node["m_ObjectId"] = ids("property-node")
        node["m_Slots"] = [{"m_Id": ids("property-slot")}]
        node["m_Property"] = {"m_Id": ids("property")}
        slot["m_ObjectId"] = ids("property-slot")
        prop["m_ObjectId"] = ids("property")
        prop["m_Guid"] = {"m_GuidSerialized": str(uuid.UUID(ids("guid")))}
        prop["m_Name"] = parameter
        prop["m_DefaultReferenceName"] = "_NMParity" + parameter
        prop["m_OverrideReferenceName"] = "_NMParity" + parameter
        prop["m_Value"] = defaults[parameter]
        graph["m_Properties"].append({"m_Id": prop["m_ObjectId"]})
        graph["m_Nodes"].append({"m_Id": node["m_ObjectId"]})
        input_ref = next(reference for reference in function["m_Slots"]
                         if function_slots[reference["m_Id"]]["m_DisplayName"] == parameter)
        graph["m_Edges"].append({
            "m_OutputSlot": {"m_Node": {"m_Id": node["m_ObjectId"]}, "m_SlotId": 0},
            "m_InputSlot": {"m_Node": {"m_Id": function["m_ObjectId"]},
                            "m_SlotId": function_slots[input_ref["m_Id"]]["m_Id"]},
        })
        objects.extend((node, slot, prop))
    uv_ref = next(reference for reference in function["m_Slots"]
                  if function_slots[reference["m_Id"]]["m_DisplayName"] == "UV")
    ids = lambda suffix: hashlib.md5((wrapper.stem + ":parity:" + suffix).encode()).hexdigest()
    node = copy.deepcopy(uv_node)
    slot = copy.deepcopy(uv_slot)
    node["m_ObjectId"] = ids("uv-node")
    node["m_Group"] = {"m_Id": ""}
    node["m_Slots"] = [{"m_Id": ids("uv-slot")}]
    slot["m_ObjectId"] = ids("uv-slot")
    graph["m_Nodes"].append({"m_Id": node["m_ObjectId"]})
    quantizer = copy.deepcopy(function)
    quantizer["m_ObjectId"] = ids("quantizer-node")
    quantizer["m_Name"] = "Quantize UV (Custom Function)"
    quantizer["m_FunctionName"] = "NM_QuantizeUV"
    quantizer["m_FunctionSource"] = QUANTIZE_GUID
    quantizer["m_Slots"] = [{"m_Id": ids("quantizer-uv")},
                            {"m_Id": ids("quantizer-resolution")},
                            {"m_Id": ids("quantizer-out")}]
    quant_slots = []
    for index, label in enumerate(("UV", "Resolution", "Out")):
        quant_slot = copy.deepcopy(function_slots[uv_ref["m_Id"]])
        quant_slot["m_ObjectId"] = ids("quantizer-" + label.lower())
        quant_slot["m_Id"] = index
        quant_slot["m_DisplayName"] = label
        quant_slot["m_ShaderOutputName"] = label
        quant_slot["m_SlotType"] = 1 if label == "Out" else 0
        value = SIZE if label == "Resolution" else 0.0
        quant_slot["m_Value"] = {"x": value, "y": value}
        quant_slot["m_DefaultValue"] = quant_slot["m_Value"].copy()
        quant_slots.append(quant_slot)
    graph["m_Nodes"].append({"m_Id": quantizer["m_ObjectId"]})
    graph["m_Edges"].append({
        "m_OutputSlot": {"m_Node": {"m_Id": node["m_ObjectId"]}, "m_SlotId": 0},
        "m_InputSlot": {"m_Node": {"m_Id": quantizer["m_ObjectId"]}, "m_SlotId": 0},
    })
    graph["m_Edges"].append({
        "m_OutputSlot": {"m_Node": {"m_Id": quantizer["m_ObjectId"]}, "m_SlotId": 2},
        "m_InputSlot": {"m_Node": {"m_Id": function["m_ObjectId"]},
                        "m_SlotId": function_slots[uv_ref["m_Id"]]["m_Id"]},
    })
    sampler = copy.deepcopy(sampler_node)
    sampler_output = copy.deepcopy(sampler_slot)
    sampler["m_ObjectId"] = ids("sampler-node")
    sampler["m_Group"] = {"m_Id": ""}
    sampler["m_Slots"] = [{"m_Id": ids("sampler-slot")}]
    sampler["m_filter"] = 1  # Point
    sampler["m_wrap"] = 1  # Clamp
    sampler_output["m_ObjectId"] = ids("sampler-slot")
    ss_ref = next(reference for reference in function["m_Slots"]
                  if function_slots[reference["m_Id"]]["m_DisplayName"] == "SS")
    graph["m_Nodes"].append({"m_Id": sampler["m_ObjectId"]})
    graph["m_Edges"].append({
        "m_OutputSlot": {"m_Node": {"m_Id": sampler["m_ObjectId"]}, "m_SlotId": 0},
        "m_InputSlot": {"m_Node": {"m_Id": function["m_ObjectId"]},
                        "m_SlotId": function_slots[ss_ref["m_Id"]]["m_Id"]},
    })
    objects.extend((node, slot, quantizer, *quant_slots, sampler, sampler_output))
    return "\n\n".join(json.dumps(item, indent=4) for item in objects) + "\n"


def main():
    unity = Path(os.environ["UNITY"])
    project = Path(os.environ["UNITY_PROJECT"]).resolve()
    if not unity.is_file() or not project.is_dir():
        raise ValueError("set UNITY and UNITY_PROJECT to a Unity binary and scratch project")
    if project == ROOT or ROOT in project.parents:
        raise ValueError("UNITY_PROJECT must be outside the repository")
    dependency = json.loads((project / "Packages/manifest.json").read_text())["dependencies"]
    PROBE.verify_source_package(dependency)
    shadergraph = next((project / "Library/PackageCache").glob("com.unity.shadergraph@*"))
    template = PROBE.multi_json(shadergraph / "GraphTemplates/BuiltIn/BuiltIn Unlit Basic.shadergraph")
    uv_sample = shadergraph / "Samples~/NodeReference/UV/TilingAndOffset.shadergraph"
    sample = PROBE.multi_json(uv_sample)
    uv_node = next(item for item in sample if item.get("m_Type") == "UnityEditor.ShaderGraph.UVNode")
    uv_slot = next(item for item in sample if item.get("m_ObjectId") == uv_node["m_Slots"][0]["m_Id"])
    sampler_sample = PROBE.multi_json(shadergraph / "Samples~/Terrain/Shaders/CNM Standard Height.shadergraph")
    sampler_node = next(item for item in sampler_sample if item.get("m_Type") == "UnityEditor.ShaderGraph.SamplerStateNode")
    sampler_slot = next(item for item in sampler_sample if item.get("m_ObjectId") == sampler_node["m_Slots"][0]["m_Id"])
    scalar_sample = PROBE.multi_json(shadergraph / "Samples~/ProductionReady/PostProcess/PostProcessHalfTone.shadergraph")
    scalar_property = next(item for item in scalar_sample if item.get("m_Type") == "UnityEditor.ShaderGraph.Internal.Vector1ShaderProperty")
    property_node = next(item for item in scalar_sample if item.get("m_Type") == "UnityEditor.ShaderGraph.PropertyNode" and item.get("m_Property", {}).get("m_Id") == scalar_property["m_ObjectId"])
    property_slot = next(item for item in scalar_sample if item.get("m_ObjectId") == property_node["m_Slots"][0]["m_Id"])
    asset_dir = project / "Assets/NMCopyParity"
    asset_dir.mkdir(parents=True, exist_ok=True)
    for old in asset_dir.glob("*.shadergraph*"):
        old.unlink()
    (asset_dir / "QuantizeUV.hlsl").write_text(
        "void NM_QuantizeUV_float(float2 UV, float2 Resolution, out float2 Out) "
        "{ Out = (floor(UV * Resolution) + 0.5) / Resolution; }\n"
    )
    (asset_dir / "QuantizeUV.hlsl.meta").write_text(
        "fileFormatVersion: 2\nguid: " + QUANTIZE_GUID + "\n"
        "ShaderIncludeImporter:\n  externalObjects: {}\n  userData: \n"
        "  assetBundleName: \n  assetBundleVariant: \n"
    )
    for name, defaults in CASES.items():
        wrapper_name = {"GlyphMapSmall": "GlyphMap", "GlyphMapLarge": "GlyphMap",
                        "CrtTiled": "Crt", "CrtScaled": "Crt",
                        "KaleidoShadow": "Kaleido", "GlitchActive": "Glitch",
                        "GlitchTiled": "Glitch", "GlitchTiledWide": "Glitch",
                        "GlitchLegacy": "Glitch",
                        "GlitchSaved": "Glitch",
                        "EffectsCga": "Effects", "EffectsCgaTiledWide": "Effects",
                        "EffectsSubpixel": "Effects", "EffectsTiled": "Effects",
                        "EffectsBlurTiled": "Effects", "EffectsCgaTiled": "Effects",
                        "EffectsSubpixelLowTiled": "Effects",
                        "EffectsSubpixelLegacy": "Effects", "EffectsCgaScaled": "Effects",
                        "EffectsSubpixelScaled": "Effects",
                        "EffectsSubpixelSaved": "Effects", "EffectsScaleMid": "Effects"}.get(name, name)
        wrapper = ROOT / "unity/com.noisemaker.hlsl/ShaderGraph/CustomFunctions" / (wrapper_name + ".hlsl")
        (asset_dir / (name + ".shadergraph")).write_text(parity_graph(
            wrapper, template, uv_node, uv_slot, sampler_node, sampler_slot,
            property_node, property_slot, scalar_property, defaults,
            saved_schema=name.endswith("Saved")))
    work = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/noisemaker-sg-copy-parity").resolve()
    work.mkdir(parents=True, exist_ok=True)
    report = work / "report.tsv"
    report.unlink(missing_ok=True)
    log = work / "unity.log"
    command = [str(unity), "-batchmode", "-quit", "-projectPath", str(project),
               "-logFile", str(log), "-executeMethod", "Noisemaker.Hlsl.Editor.NMShaderGraphParityProbe.Run",
               "-nmParityDir", "Assets/NMCopyParity", "-nmParityReport", str(report),
               "-nmParityCaptures", str(work)]
    result = subprocess.run(command, check=False)
    if not report.is_file():
        raise RuntimeError(f"Unity wrote no parity report (exit {result.returncode}); see {log}")
    rows = [line.split("\t") for line in report.read_text().splitlines()]
    if len(rows) != len(CASES) or {row[0] for row in rows} != set(CASES):
        raise RuntimeError(f"parity report incomplete: {report}")
    print(report.read_text(), end="")
    if result.returncode or any(row[1] != "PASS" for row in rows):
        raise RuntimeError(f"Shader Graph copy parity failed; see {log} and {report}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f"shadergraph-copy-parity-verify: {error}", file=sys.stderr)
        sys.exit(1)
