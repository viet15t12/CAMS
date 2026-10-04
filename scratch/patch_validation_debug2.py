with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "r") as f:
    text = f.read()

prefix, validate_rest = text.split("def validate_payload", 1)

new_validate = """def validate_payload(payload: dict[str, Any], *, existing: bool = False) -> dict[str, Any]:
    try:
""" + validate_rest.replace("    normalized = dict(payload)", "    normalized = dict(payload)").replace("    return normalized", """    return normalized
    except Exception as e:
        print("CRITICAL PAYLOAD DEBUG:", payload)
        raise""")

with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "w") as f:
    f.write(prefix + new_validate)

