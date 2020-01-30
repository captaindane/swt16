import xml.etree.ElementTree as ET
import getopt, sys

# Function: decompose a direct, displaced address into register and displacement
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


# Function: Generate binary
def gen_binary ( lines, instr_list, label_list, out_filename ):

    fhandle = open ( out_filename, "w")
    pc      = 0
    
    for line in lines:

        # Decompose line into individual elements
        elem_list = line.replace(',', ' ').split()

        # Get first match comapring mnemonic of current line against instruction list
        instr_desc = next((i for i in instr_list if i["mnemonic"].lower() == elem_list[0].lower()), ({ "mnemonic": "invalid", "cycles": "0", "Type": "invalid"}))
                
        opc    = hex(int(instr_desc["opc"], 2))[2:]
        field1 = ""
        field2 = ""
        field3 = ""
        immB   = ""

#       print "DBG: now interpreting line: " + line
        
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
                    immB   = parse_imm(displacement, "B", label_list, instr_desc, pc)
            # Handle register 
            else:
                field3 = hex(int(elem_list[2][1:]))[2:]
                if (instr_desc["cycles"] == "2"):
                    immB = parse_imm(elem_list[3], "B", label_list, instr_desc, pc)

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
                field3 = parse_imm(elem_list[2], "A", label_list, instr_desc, pc)

            elif (instr_desc["cycles"] == "2"):
                field3 = "0"
                immB   = parse_imm(elem_list[2], "B", label_list, instr_desc, pc)

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
                    immB   = parse_imm(displacement, "B", label_list, instr_desc, pc)
            # Handle register 
            else:
                field2 = hex(int(elem_list[2][1:]))[2:]
            
            field3 = hex(int(instr_desc["func3"], 2))[2:]

        else:
            print "ERROR: Cannot interpret line " + line
        
        # Increment program counter
        if   (instr_desc["cycles"] == "1"):
            pc = pc + 2;
        elif (instr_desc["cycles"] == "2"):
            pc = pc + 4;
        
        # Write instruction to output file
        fhandle.write ( (field3 + field2 + field1 + opc).upper() + "  //" + line + "\n" )
        
        if (instr_desc["cycles"] == "2"):
            fhandle.write ( immB.upper() + "\n")

    # End: for (line in lines):

    # Close output file
    fhandle.close()


# Function: is input string a direct (displaced) address?
def is_direct_address ( str_value ):
    
    is_addr = False

    found_open  = str_value.find('(');
    found_close = str_value.find(')');

    if ( found_open >= 0 and found_close > 0 and (found_close > found_open) ):
        is_addr = True

    return is_addr


## Function: parse_imm
#  Parse immediate value. Input format is hex, binary, or decimal. Output format is hex.
# 
#  param  str_value : value to be interpreded as immediate
#  param  imm_type  : type of immedate value ("A", "B")
#  param  label_list: list of all valid labels
#  param  instr_desc: descriptor if instruction whose immedate value is given by "str_value"
#  param  pc        : program counter (for conversion of labels to pc-relative addresses)
#
def parse_imm ( str_value, imm_type, label_list, instr_desc, pc ):

    num_hex_digits = 0;
    parsed = "z"
    
    # Size of immediate field in instruction in units of hex digits (i.e., 4 bits)
    if (imm_type == "A"):
        num_hex_digits = 1
    elif (imm_type == "B"):
        num_hex_digits = 4

    num_bits = num_hex_digits*4

    # If immediate value is a label, get the label entry from the label list
    my_label = next((label for label in label_list if label["name"] == str_value), ({"name": "invalid", "pc": 0}))

    # Immediate is not a label:
    if (my_label["name"] == "invalid"):

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

    # Immediate is a label. Treat label depending on whether instruction uses PC-relative or absolute, direct addressing
    else:
        if (instr_desc["addr_mode"] == "abs"):
            parsed = hex(my_label["pc"])[2:].zfill(num_hex_digits)
        elif (instr_desc["addr_mode"] == "pc_rel"):
            int_val = my_label["pc"] - pc
            parsed  = hex((int_val + (1<<num_bits)) % (1 << num_bits))[2:].zfill(num_hex_digits)
        else:
            print "ERROR: instruction " + instr_desc["name"] + " not suited for label translation."
            sys.exit(2)
            

    return parsed


# Function: Parse ISA from XML description
def parse_isa(root, instr_list, depth, root_opc="0000"):
    
    for child in root:
        
        if child.tag == "instr":
            
            # Root instruction
            if depth == 0:
                instr_list.append ( { "mnemonic": child.attrib["name"], "opc": child.attrib["opc"], "cycles": child.attrib["cycles"], "addr_mode": child.attrib["addr_mode"], "Type": "R" } )
            
            # Hierarchical instruction
            else:
                # S-Type, which has func1 attribute
                if "func1" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "cycles": child.attrib["cycles"], "addr_mode": child.attrib["addr_mode"], "func1": child.attrib["func1"], "Type": "S" } )

                # U-Type, which has func2 attribute
                elif "func2" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "cycles": child.attrib["cycles"], "addr_mode": child.attrib["addr_mode"], "func2": child.attrib["func2"], "Type": "U" } )

                # J-Type, which has func3 attribute
                elif "func3" in child.attrib:
                    instr_list.append ( { "mnemonic": child.attrib["name"], "opc": root_opc, "cycles": child.attrib["cycles"], "addr_mode": child.attrib["addr_mode"], "func3": child.attrib["func3"], "Type": "J" } )

        # Recursive call if we are in root of hierarchical instruction
        elif child.tag == "root":
            parse_isa(child, instr_list, depth+1, child.attrib["opc"])


# Function: Preporcess assembly program. Return a list of all labels.
def preproc ( asm_lines, instr_list ):

    pc            = 0
    label_list    = []
    asm_lines_out = []

    for line in asm_lines:

        # Decompose line into individual elements
        elem_list = line.replace(',', ' ').split()
    
        # Get first match comapring mnemonic of current line against instruction list
        instr_desc = next((i for i in instr_list if i["mnemonic"].lower() == elem_list[0].lower()), ({ "cycles": "0"}))
    
        # Current line is a label
        if (":" in line) and (line.find(":") > 0):
            
            label_list.append( { "pc": pc, "name": line[0:line.find(":")] } )

        # Current line is 1-cycle instruction
        elif (instr_desc["cycles"] == "1"):
            
            pc = pc + 2;
            asm_lines_out.append(line)

        # Current line is 2-cycle instruction
        elif (instr_desc["cycles"] == "2"):

            pc = pc + 4;
            asm_lines_out.append(line)

        # Line cannot be interpreted
        else:

            print "ERROR: Preprocessor cannot interpret line: " + line
            sys.exit(1)

    return label_list, asm_lines_out

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



asm_in   = ""
asm_out  = ""
isa_desc = "isa.xml"
silent   = False

# Parse command line
try:
    opts, args = getopt.getopt(sys.argv[1:], "i:o:d:s", ["input", "output", "isa desc", "silent"])
except getopt.GetoptError as err:
    print str(err)
    sys.exit(2)

# Evaluate parameters
for opt, val in opts:
    if (opt == "-i"):
        asm_in = val
    elif (opt == "-o"):
        asm_out = val
    elif (opt == "-d"):
        isa_desc = val
    elif (opt == "-s"):
        silent = True

if (asm_in == ""):
    print "ERROR: no input file specified"
    sys.exit(2)

elif (asm_out == ""):
    if (".asm" in asm_in):
        asm_out = asm_in.replace(".asm", ".pmem")
    else:
        asm_out = asm_in + ".hex"

if (not silent):
    print "========================================="
    print "SWT16 assembler invoked."
    print "input : " + asm_in 
    print "output: " + asm_out
    print "isa   : " + isa_desc
    print "========================================="

# Parse XML file
tree = ET.parse(isa_desc)
root = tree.getroot()

# Parse ISA from XML
instr_list = []
depth = 0
parse_isa(root, instr_list, depth)

# Strip white spaces and comments from ASM file
asm_lines = strip_asm ( asm_in )

# Preprocessing
label_list, asm_lines_pp = preproc ( asm_lines, instr_list )

# Generate binary
gen_binary ( asm_lines_pp, instr_list, label_list, asm_out )

