with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "r") as f:
    text = f.read()

new_except = """    except Exception as e:
        import traceback
        with open("/tmp/cams_debug_payload.log", "w") as out:
            out.write("CRITICAL PAYLOAD DEBUG: " + str(payload) + "\\n")
            out.write(traceback.format_exc())
        raise"""

text = text.replace("""    except Exception as e:
        print("CRITICAL PAYLOAD DEBUG:", payload)
        raise""", new_except)

with open("/data/Projects/CAMS_2/features/interfaces/validation.py", "w") as f:
    f.write(text)

