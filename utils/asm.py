import xml.etree.ElementTree as ET

# Function: Parse ISA from XML description
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


# Function: Strip white spaces and comments from ASM file
def strip_asm ( filename ):
    
    asm_list = [];
    
    file_handler = open ( filename, "r")
    
    for line in file_handler:
        
        # Trim leading and trailing white spaces
        trimmed = line.strip()
        
        # Ignore lines that are comments
        if (trimmed[0:1] != ";"):
            
            # Remove partial comments from lines
            pos = trimmed.find(";")

            nocomment = trimmed
            
            if (pos != -1):
                nocomment = trimmed[0:pos].strip()

            asm_list.append(nocomment);

    file_handler.close();

    return asm_list;


# Function: Generate binary
def gen_binary ( lines, instr_list ):

    for line in lines:

        # Decompose line into individual elements
        elem_list = line.replace(',', ' ').split()

        if ( len(elem_list) >= 1 ):

            match_list = [i for i in instr_list if i["mnemonic"].lower() == elem_list[0].lower()]

            if ( len(match_list) > 0 ):
                
                instr_desc = match_list[0];

                opc    = hex(int(instr_desc["opc"], 2))[2:]
                field1 = ""
                field2 = ""
                field3 = ""
                immB   = ""

                if (instr_desc["Type"] == "R"):

                    field1 = hex(int(elem_list[1][1:]))[2:]
                    field2 = hex(int(elem_list[2][1:]))[2:]
                    field3 = hex(int(elem_list[3][1:]))[2:]

                    print line + " -> " + field3 + field2 + field1 + opc

            else:

                print "ERROR: Cannot interpret line " + line



# Parse XML file
tree = ET.parse('isa.xml')
root = tree.getroot()

# Parse ISA from XML
instr_list = []
depth = 0
parse_isa(root, instr_list, depth)

# Strip white spaces and comments from ASM file
asm_lines = strip_asm ( "../prog/hex_test_arith.asm")

# Generate binary
gen_binary ( asm_lines, instr_list )

