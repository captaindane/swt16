import xml.etree.ElementTree as ET
import getopt, sys

# Function: is input string a direct (displaced) address?
def is_direct_address ( str_value ):
    
    is_addr = False

    found_open  = str_value.find('(');
    found_close = str_value.find(')');

    if ( found_open >= 0 and found_close > 0 and (found_close > found_open) ):
        is_addr = True

    return is_addr


# Function:
def decompose_direct_address ( str_value ):

    str_disp     = ""
    stripped     = str_value.strip();

    pos_open     = stripped.find('(');
    pos_close    = stripped.find(')');

    # There is a deplacement value before '('
    if (pos_open > 0):
        
        str_disp = stripped[0:pos_open]

    reg = stripped[pos_open+1:pos_close]

    return [reg, str_disp]




# Function: Parse ISA from XML description
def parse_isa(root, instr_list, depth, root_opc="0000"):
    
    for child in root:
        
        if child.tag == "instr":
            
            # Root instruction
            if depth == 0:
                instr_list.append ( { "mnemonic": child.attrib["name"], "opc": child.attrib["opc"], "cycles": child.attrib["cycles"], "Type": "R" } )
            
            # Hierarchical instruction
            else:
                # S-Type, which has func1 attribute
                if "func1" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "cycles": child.attrib["cycles"], "func1": child.attrib["func1"], "Type": "S" } )

                # U-Type, which has func2 attribute
                elif "func2" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "cycles": child.attrib["cycles"], "func2": child.attrib["func2"], "Type": "U" } )

                # J-Type, which has func3 attribute
                elif "func3" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "cycles": child.attrib["cycles"], "func3": child.attrib["func3"], "Type": "J" } )

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


# Function: Parse immediate value. Input format is hex, binary, or decimal. Output format is hex.
def parse_imm ( str_value, imm_type ):

    num_hex_digits = 0;
    parsed = "z"
    
    # Size of immediate field in instruction in units of hex digits (i.e., 4 bits)
    if (imm_type == "A"):
        num_hex_digits = 1
    elif (imm_type == "B"):
        num_hex_digits = 4

    num_bits = num_hex_digits*4

    # Input is hex
    if ( str_value[0:2] == "0x"):
        parsed = str_value[2:].zfill(num_hex_digits)
        
    
    # Input is binary
    elif ( str_value[0:2] == "0b"):
        parsed = hex(int(str_value[2:], 2))[2:].zfill(num_hex_digits)

    # Input is decimal
    else:
        int_val = int(str_value, 10)
        parsed  = hex((int_val + (1<<num_bits)) % (1 << num_bits))[2:].zfill(num_hex_digits)

    return parsed


# Function: Generate binary
def gen_binary ( lines, instr_list, out_filename ):

    fhandle = open ( out_filename, "w")
    
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

#               print "DBG: now interpreting line: " + line
                
                # R-Type
                # +=======+=======+=======+=======+
                # |  rs2  |  rs1  |   rd  |  opc  |
                # +=======+=======+=======+=======+
                if (instr_desc["Type"] == "R"):

                    field1 = hex(int(elem_list[1][1:]))[2:]
                    field2 = hex(int(elem_list[2][1:]))[2:]
                    field3 = hex(int(elem_list[3][1:]))[2:]

                # S-Type
                # +=======+=======+=======+=======+
                # |  rs2  |  rs1  | func1 |  opc  |
                # +=======+=======+=======+=======+
                # |        immB (optional)        |
                # +===============================+
                elif (instr_desc["Type"] == "S"):
                    
                    field1 = hex(int(instr_desc["func1"], 2))[2:]
                    field2 = hex(int(elem_list[1][1:]))[2:]
                    field3 = ""

                    # Handle direct address (store half instruction)
                    if (is_direct_address(elem_list[2])):
                        [reg, displacement] = decompose_direct_address ( elem_list[2] )
                        field3 = hex(int(reg[1:]))[2:]
                        if (instr_desc["cycles"] == "2"):
                            immB   = parse_imm(displacement, "B")
                    # Handle register 
                    else:
                        field3 = hex(int(elem_list[2][1:]))[2:]
                        if (instr_desc["cycles"] == "2"):
                            immB = parse_imm(elem_list[3], "B")

                # U-Type
                # +=======+=======+=======+=======+
                # |  immA | func2 |   rd  |  opc  |
                # +=======+=======+=======+=======+
                # |        immB (optional)        |
                # +===============================+
                elif (instr_desc["Type"] == "U"):
                    
                    field1 = hex(int(elem_list[1][1:]))[2:]
                    field2 = hex(int(instr_desc["func2"], 2))[2:]

                    if (instr_desc["cycles"] == "1"):
                        field3 = parse_imm(elem_list[2], "A")

                    elif (instr_desc["cycles"] == "2"):
                        field3 = "0"
                        immB   = parse_imm(elem_list[2], "B")

                # J-Type
                # +=======+=======+=======+=======+
                # | func3 |  rs1  |   rd  |  opc  |
                # +=======+=======+=======+=======+
                # |        immB (optional)        |
                # +===============================+
                elif (instr_desc["Type"] == "J"):
                    
                    field1 = hex(int(elem_list[1][1:]))[2:]
                    
                    # Handle direct address (store half instruction)
                    if (is_direct_address(elem_list[2])):
                        [reg, displacement] = decompose_direct_address ( elem_list[2] )
                        field2 = hex(int(reg[1:]))[2:]
                        if (instr_desc["cycles"] == "2"):
                            immB   = parse_imm(displacement, "B")
                    # Handle register 
                    else:
                        field2 = hex(int(elem_list[2][1:]))[2:]
                    
                    field3 = hex(int(instr_desc["func3"], 2))[2:]

                # Write instruction to output file
                fhandle.write ( (field3 + field2 + field1 + opc).upper() + "  //" + line + "\n" )
                
                if (instr_desc["cycles"] == "2"):
                    fhandle.write ( immB.upper() + "\n")
            
            else:
                print "ERROR: Cannot interpret line " + line

    # Close output file
    fhandle.close()


asm_in  = ""
asm_out = ""

# Parse command line
try:
    opts, args = getopt.getopt(sys.argv[1:], "i:o:", ["input", "output"])
except getopt.GetoptError as err:
    print str(err)
    sys.exit(2)

# Evaluate parameters
for opt, val in opts:
    if (opt == "-i"):
        asm_in = val
    elif (opt == "-o"):
        asm_out = val

if (asm_in == ""):
    print "ERROR: no input file specified"
    sys.exit(2)

elif (asm_out == ""):
    if (".asm" in asm_in):
        asm_out = asm_in.replace(".asm", ".pmem")
    else:
        asm_out = asm_in + ".hex"

print "========================================="
print "SWT16 assembler invoked."
print "input : " + asm_in 
print "output: " + asm_out
print "========================================="

# Parse XML file
tree = ET.parse('isa.xml')
root = tree.getroot()

# Parse ISA from XML
instr_list = []
depth = 0
parse_isa(root, instr_list, depth)

# Strip white spaces and comments from ASM file
asm_lines = strip_asm ( asm_in )

# Generate binary
gen_binary ( asm_lines, instr_list, asm_out )

