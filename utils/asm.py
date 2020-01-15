import xml.etree.ElementTree as ET

# Parse ISA from XML description
def parse_isa(root, instr_list, depth, root_opc="0000"):
    
    for child in root:
        
        if child.tag == "instr":
            
            # Root instruction
            if depth == 0:
                instr_list.append ( { "mnemonic": child.attrib["name"], "opc": child.attrib["opc"], "Type": "R" } )
            
            # Hierarchical instruction
            else:
                # S-Type, which has func1 attribute
                if "func1" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "func1": child.attrib["func1"], "Type": "S" } )

                # U-Type, which has func2 attribute
                elif "func2" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "func2": child.attrib["func2"], "Type": "U" } )

                # J-Type, which has func3 attribute
                elif "func3" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "func3": child.attrib["func3"], "Type": "J" } )

        # Recursive call if we are in root of hierarchical instruction
        elif child.tag == "root":
            parse_isa(child, instr_list, depth+1, child.attrib["opc"])

# Parse XML file
tree = ET.parse('isa.xml')
root = tree.getroot()

# Parse ISA from XML
instr_list = []
depth = 0
parse_isa(root, instr_list, depth)

print instr_list

