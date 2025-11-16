#!/bin/bash

# Simple bash script that renames the melon attribute Company into empty string. Which makes mods to be attempted
# to load regardless the company name

######## CONFIG ########################################################################################
# Change this path to match your melon loader installation (we're using their bundled Mono.Cecil.dll)
cecilPath="/home/shiro/.local/share/Steam/steamapps/common/ChilloutVR/MelonLoader/net35/Mono.Cecil.dll"
# Change this path to a folder where your mods are located, it will then output the fixed mods into a
# folder named ~RenamedCompanyMods, inside of the picked folder
sourceDir="/home/shiro/.local/share/Steam/steamapps/common/ChilloutVR/Mods/"
######## CONFIG ########################################################################################

# Check if mono is installed
if ! command -v mono &> /dev/null; then
    echo "mono could not be found, please install mono to run this script."
    exit 1
fi

# Create output directory if it doesn't exist
outputDir="${sourceDir}/~RenamedCompanyMods"
mkdir -p "$outputDir"

# Temporary C# program to modify the DLLs using Mono.Cecil
read -r -d '' csharpCode << 'EOF'
using System;
using System.IO;
using Mono.Cecil;

class Program {
    static int Main(string[] args) {
        if (args.Length < 2) {
            Console.WriteLine("Usage: modifydll <input.dll> <output.dll>");
            return 1;
        }
        string inputPath = args[0];
        string outputPath = args[1];

        try {
            var readerParams = new ReaderParameters { ReadWrite = false };
            var assembly = AssemblyDefinition.ReadAssembly(inputPath, readerParams);
            var module = assembly.MainModule;

            var attr = module.Assembly.CustomAttributes;
            bool found = false;
            foreach (var a in attr) {
                if (a.AttributeType.FullName == "MelonLoader.MelonGameAttribute") {
                    var stringType = module.TypeSystem.String;
                    a.ConstructorArguments[0] = new CustomAttributeArgument(stringType, "");
                    a.ConstructorArguments[1] = new CustomAttributeArgument(stringType, "ChilloutVR");
                    found = true;
                    break;
                }
            }

            if (found) {
                assembly.Write(outputPath);
                Console.WriteLine($"Modified and saved to: {outputPath}");
            } else {
                Console.WriteLine($"No MelonGame attribute found in: {Path.GetFileName(inputPath)}");
            }
            return 0;
        } catch (Exception e) {
            Console.WriteLine($"Failed to process {inputPath}: {e.Message}");
            return 1;
        }
    }
}
EOF

# Write the C# code to a temp file
tmpdir=$(mktemp -d)
csfile="$tmpdir/modifydll.cs"
exeFile="$tmpdir/modifydll"
cp $cecilPath "$tmpdir/Mono.Cecil.dll"
echo "$csharpCode" > "$csfile"

# Compile the C# program with Mono.Cecil.dll reference
mcs -reference:"$cecilPath" -out:"$exeFile" "$csfile"
if [ $? -ne 0 ]; then
    echo "Failed to compile the C# helper program."
    # rm -rf "$tmpdir"
    exit 1
fi

# Process each DLL file
shopt -s nullglob
dllFiles=("$sourceDir"/*.dll)
for dll in "${dllFiles[@]}"; do
    echo "Processing: $(basename "$dll")"
    outputPath="$outputDir/$(basename "$dll")"
    mono "$exeFile" "$dll" "$outputPath"
done

# Cleanup
rm -rf "$tmpdir"