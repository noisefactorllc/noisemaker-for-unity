#!/usr/bin/env python3
"""Compile every wrapper through Shader Graph nodes and direct HLSL calls."""

import copy
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WRAPPERS = ROOT / "unity/com.noisemaker.hlsl/ShaderGraph/CustomFunctions"
EXPECTED_COUNT = 138
INITIALIZERS = {
    "float": "1.0",
    "int": "1",
    "float2": "float2(0.5, 0.5)",
    "float3": "float3(0.5, 0.5, 0.5)",
    "float4": "float4(0.5, 0.5, 0.5, 0.5)",
    "UnityTexture2D": "UnityBuildTexture2DStructNoScaleNoTexelSize(_ProbeTex)",
    "UnitySamplerState": "UnityBuildSamplerStateStruct(sampler_ProbeTex)",
}


def wrapper_signature(wrapper: Path):
    source = wrapper.read_text()
    match = re.search(r"^void\s+(NM_\w+_float)\s*\((.*?)\)\s*\{", source, re.S | re.M)
    if not match:
        raise ValueError(f"no Custom Function entry in {wrapper}")
    signature = re.sub(r"//[^\n]*", "", match.group(2))
    parameters = []
    for parameter in signature.split(","):
        words = parameter.strip().split()
        if len(words) == 3 and words[:2] == ["out", "float4"]:
            parameters.append(("float4", words[2], True))
        elif len(words) == 2 and words[0] in INITIALIZERS:
            parameters.append((words[0], words[1], False))
        else:
            raise ValueError(f"unsupported Custom Function parameter in {wrapper}: {parameter}")
    if sum(output for _, _, output in parameters) != 1:
        raise ValueError(f"expected one float4 output in {wrapper}")
    return match.group(1), parameters


def generate_shader(wrapper: Path) -> str:
    function, parameters = wrapper_signature(wrapper)
    declarations = []
    arguments = []
    output = None
    for index, (kind, name, is_output) in enumerate(parameters):
        if is_output:
            declarations.append(f"float4 arg{index} = float4(0, 0, 0, 0);")
            output = f"arg{index}"
        else:
            value = INITIALIZERS[kind]
            if name == "Resolution":
                value = "float2(128.0, 128.0)"
            elif name == "Time":
                value = "0.25"
            declarations.append(f"{kind} arg{index} = {value};")
        arguments.append(f"arg{index}")

    body = "\n            ".join(declarations)
    call = f"{function}({', '.join(arguments)});"
    return f'''Shader "Hidden/NMWrapperProbe/{wrapper.stem}"
{{
    SubShader {{ Pass {{
        HLSLPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 4.5
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        float4 _Time;
        #include "Packages/com.noisemaker.hlsl/ShaderGraph/CustomFunctions/{wrapper.name}"
        TEXTURE2D(_ProbeTex);
        SAMPLER(sampler_ProbeTex);
        float4 vert(uint id : SV_VertexID) : SV_POSITION {{
            float2 uv = float2((id << 1) & 2, id & 2);
            return float4(uv * 2.0 - 1.0, 0.0, 1.0);
        }}
        float4 frag(float4 pos : SV_POSITION) : SV_Target {{
            {body}
            {call}
            return {output};
        }}
        ENDHLSL
    }} }}
    Fallback Off
}}
'''


def multi_json(path: Path):
    source = path.read_text()
    decoder = json.JSONDecoder()
    objects = []
    while source.strip():
        source = source.lstrip()
        item, length = decoder.raw_decode(source)
        objects.append(item)
        source = source[length:]
    return objects


def generate_graph(wrapper: Path, template):
    function, parameters = wrapper_signature(wrapper)
    meta = wrapper.with_name(wrapper.name + ".meta").read_text()
    match = re.search(r"^guid: ([0-9a-f]{32})$", meta, re.M)
    if not match:
        raise ValueError(f"wrapper has no .meta GUID: {wrapper}")
    ids = lambda suffix: hashlib.md5((wrapper.stem + ":" + suffix).encode()).hexdigest()
    objects = copy.deepcopy(template)
    graph = objects[0]
    base_color = next(
        item for item in objects
        if item.get("m_Type", "").endswith("BlockNode")
        and item.get("m_SerializedDescriptor") == "SurfaceDescription.BaseColor"
    )
    texture_property = next(
        item for item in objects
        if item.get("m_Type", "").endswith("PropertyNode")
        and any(property_item.get("m_ObjectId") == item.get("m_Property", {}).get("m_Id")
                and property_item.get("m_Type", "").endswith("Texture2DShaderProperty")
                for property_item in objects)
    )
    graph["m_Edges"] = [
        edge for edge in graph["m_Edges"]
        if edge["m_InputSlot"]["m_Node"]["m_Id"] != base_color["m_ObjectId"]
    ]
    node = {
        "m_SGVersion": 1,
        "m_Type": "UnityEditor.ShaderGraph.CustomFunctionNode",
        "m_ObjectId": ids("node"),
        "m_Group": {"m_Id": ""},
        "m_Name": function[:-6] + " (Custom Function)",
        "m_DrawState": {"m_Expanded": True, "m_Position": {
            "serializedVersion": "2", "x": -400.0, "y": 200.0,
            "width": 250.0, "height": 300.0}},
        "m_Slots": [], "synonyms": ["code", "HLSL"],
        "m_Precision": 0, "m_PreviewExpanded": False,
        "m_DismissedVersion": 0, "m_PreviewMode": 0,
        "m_CustomColors": {"m_SerializableColors": []},
        "m_SourceType": 0, "m_FunctionName": function[:-6],
        "m_FunctionSource": match.group(1),
        "m_FunctionSourceUsePragmas": True, "m_FunctionBody": "",
    }
    graph["m_Nodes"].append({"m_Id": node["m_ObjectId"]})
    objects.append(node)
    slot_types = {
        "float": "Vector1MaterialSlot", "int": "Vector1MaterialSlot",
        "float2": "Vector2MaterialSlot", "float3": "Vector3MaterialSlot",
        "float4": "Vector4MaterialSlot", "UnityTexture2D": "Texture2DMaterialSlot",
        "UnitySamplerState": "SamplerStateMaterialSlot",
    }
    output_index = None
    for index, (kind, name, is_output) in enumerate(parameters):
        slot = {
            "m_SGVersion": 0,
            "m_Type": "UnityEditor.ShaderGraph." + slot_types[kind],
            "m_ObjectId": ids(f"slot{index}"), "m_Id": index,
            "m_DisplayName": name, "m_SlotType": 1 if is_output else 0,
            "m_Hidden": False, "m_ShaderOutputName": name,
            "m_StageCapability": 3,
        }
        if kind in ("UnityTexture2D", "UnitySamplerState"):
            slot["m_BareResource"] = False
            if kind == "UnityTexture2D":
                graph["m_Edges"].append({
                    "m_OutputSlot": {"m_Node": {"m_Id": texture_property["m_ObjectId"]}, "m_SlotId": 0},
                    "m_InputSlot": {"m_Node": {"m_Id": node["m_ObjectId"]}, "m_SlotId": index},
                })
        else:
            value = 0.0 if is_output else (128.0 if name == "Resolution" else 0.25 if name == "Time" else 0.5)
            if kind in ("float", "int"):
                slot["m_Value"] = value
                slot["m_DefaultValue"] = value
            else:
                coordinates = "xyzw"[:int(kind[-1])]
                slot["m_Value"] = {coordinate: value for coordinate in coordinates}
                slot["m_DefaultValue"] = slot["m_Value"].copy()
            slot["m_Labels"] = []
        node["m_Slots"].append({"m_Id": slot["m_ObjectId"]})
        objects.append(slot)
        if is_output:
            output_index = index
    graph["m_Edges"].append({
        "m_OutputSlot": {"m_Node": {"m_Id": node["m_ObjectId"]}, "m_SlotId": output_index},
        "m_InputSlot": {"m_Node": {"m_Id": base_color["m_ObjectId"]}, "m_SlotId": 0},
    })
    return "\n\n".join(json.dumps(item, indent=4) for item in objects) + "\n"


def main() -> int:
    unity = os.environ.get("UNITY")
    project_name = os.environ.get("UNITY_PROJECT")
    if not unity or not Path(unity).is_file() or not project_name:
        raise ValueError("set UNITY to the Unity binary and UNITY_PROJECT to a scratch Unity project")
    project = Path(project_name).resolve()
    if project == ROOT or ROOT in project.parents:
        raise ValueError("UNITY_PROJECT must be outside the repository")
    package_cache = project / "Library/PackageCache"
    if not list(package_cache.glob("com.unity.shadergraph@*")) or not list(
        package_cache.glob("com.unity.render-pipelines.core@*")
    ):
        raise ValueError("UNITY_PROJECT must have Shader Graph and SRP Core resolved")
    manifest = json.loads((project / "Packages/manifest.json").read_text())
    dependency = manifest.get("dependencies", {})
    if not any(name in dependency for name in (
        "com.unity.shadergraph", "com.unity.render-pipelines.universal",
        "com.unity.render-pipelines.high-definition",
    )):
        raise ValueError("UNITY_PROJECT must declare Shader Graph or an SRP that depends on it")
    expected_package = (ROOT / "unity/com.noisemaker.hlsl").resolve()
    package = dependency.get("com.noisemaker.hlsl", "")
    if not package.startswith("file:") or Path(package[5:]).resolve() != expected_package:
        raise ValueError(f"UNITY_PROJECT must use the current package: {expected_package}")
    shadergraph_package = next(package_cache.glob("com.unity.shadergraph@*"))
    template = multi_json(shadergraph_package / "GraphTemplates/BuiltIn/BuiltIn Unlit Basic.shadergraph")

    wrappers = sorted(WRAPPERS.glob("*.hlsl"))
    if len(wrappers) != EXPECTED_COUNT:
        raise ValueError(f"expected {EXPECTED_COUNT} wrappers, found {len(wrappers)}")
    asset_directory = project / "Assets/NMWrapperCompileProbes"
    asset_directory.mkdir(parents=True, exist_ok=True)
    for pattern in ("*.shader", "*.shader.meta", "*.shadergraph", "*.shadergraph.meta"):
        for old in asset_directory.glob(pattern):
            old.unlink()
    for wrapper in wrappers:
        (asset_directory / (wrapper.stem + ".shader")).write_text(generate_shader(wrapper))
        (asset_directory / (wrapper.stem + ".shadergraph")).write_text(generate_graph(wrapper, template))

    work = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/noisemaker-shadergraph-verify").resolve()
    work.mkdir(parents=True, exist_ok=True)
    captures = work / "captures"
    captures.mkdir(exist_ok=True)
    report = work / "report.tsv"
    log = work / "unity.log"
    report.unlink(missing_ok=True)
    for old in captures.glob("*.png"):
        old.unlink()
    command = [
        unity, "-batchmode", "-quit", "-projectPath", str(project),
        "-logFile", str(log), "-executeMethod",
        "Noisemaker.Hlsl.Editor.NMShaderGraphCompileProbe.Run",
        "-nmProbeDir", "Assets/NMWrapperCompileProbes",
        "-nmProbeReport", str(report), "-nmProbeCaptures", str(captures),
        "-nmProbeExpected", str(2 * EXPECTED_COUNT),
    ]
    completed = subprocess.run(command, check=False)
    if not report.is_file():
        raise RuntimeError(f"Unity wrote no report (exit {completed.returncode}); see {log}")
    rows = [line.split("\t", 2) for line in report.read_text().splitlines()]
    expected_names = {wrapper.stem + suffix for wrapper in wrappers for suffix in ("-raw", "-graph")}
    names = [row[0] for row in rows]
    if len(rows) != 2 * EXPECTED_COUNT or len(set(names)) != 2 * EXPECTED_COUNT or set(names) != expected_names:
        raise RuntimeError(f"report does not cover both paths for all {EXPECTED_COUNT} wrappers; see {report}")
    failures = [row for row in rows if len(row) < 2 or row[1] != "PASS"]
    missing_captures = [name for name in names if not (captures / (name + ".png")).is_file()]
    print(f"Shader Graph wrappers: {2 * EXPECTED_COUNT - len(failures)}/{2 * EXPECTED_COUNT} compiled and rendered")
    if failures:
        for row in failures:
            print("\t".join(row), file=sys.stderr)
    if completed.returncode or failures or missing_captures:
        raise RuntimeError(f"wrapper gate failed; Unity exit {completed.returncode}, "
                           f"{len(failures)} compile failures, {len(missing_captures)} missing captures; see {log}")
    print(f"report: {report}; captures: {captures}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as error:
        print(f"shadergraph-compile-verify: {error}", file=sys.stderr)
        sys.exit(1)
